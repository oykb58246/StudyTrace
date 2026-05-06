import {
  HttpException,
  HttpStatus,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { startOfToday } from '../../common/date-range';
import { PrismaService } from '../../prisma/prisma.service';
import { ChatDto, FlashCardsDto, RiskWarningsDto, TextInputDto, WeeklyAnalysisDto } from './dto/ai-common.dto';
import { assistantSystemPrompt, systemJsonPrompt } from './ai-prompts';

type Provider = 'blueheart' | 'deepseek';

type ModelRuntime = {
  provider: Provider;
  apiKey: string;
  baseUrl: string;
  model: string;
};

@Injectable()
export class AiService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  generateStudyLog(userId: string, dto: TextInputDto) {
    return this.callJson(userId, 'study-log', [
      { role: 'system', content: `${systemJsonPrompt} 你需要把大学生的自然语言学习描述整理成结构化学习日志。` },
      { role: 'user', content: `请根据输入生成 JSON：{"courseName":"","content":"","problems":"","thoughts":"","nextPlan":""}\n输入：${dto.input}` },
    ]);
  }

  generateTaskPlan(userId: string, dto: TextInputDto) {
    return this.callJson(userId, 'task-plan', [
      { role: 'system', content: `${systemJsonPrompt} 你需要把复杂学习任务拆成可执行计划。` },
      {
        role: 'user',
        content:
          `今天：${new Date().toISOString()}\n请生成 JSON：{"mainTitle":"","taskType":"classHomework|paperReading|programmingHomework|labReport|projectDev|examReview|readingNotes|other","courseName":"","deadline":"ISO8601","difficulty":"较轻松|中等|困难","subTasks":[""],"plannedSubTasks":[{"title":"","deadline":"ISO8601","note":""}],"schedule":""}\n输入：${dto.input}`,
      },
    ]);
  }

  generateWeeklyAnalysis(userId: string, dto: WeeklyAnalysisDto) {
    return this.callJson(userId, 'weekly-analysis', [
      { role: 'system', content: `${systemJsonPrompt} 你需要根据学习日志和任务数据生成分析型学习周报。` },
      {
        role: 'user',
        content:
          `分析周期：${dto.startDate} 至 ${dto.endDate}\n学习日志：${JSON.stringify(dto.logs)}\n任务：${JSON.stringify(dto.tasks)}\n请生成 JSON：{"mainTopics":"","courseDistribution":"","frequentProblems":"","completedTasks":"","riskTasks":"","statusEvaluation":"","nextWeekPriority":""}`,
      },
    ]);
  }

  generateRiskWarnings(userId: string, dto: RiskWarningsDto) {
    return this.callJson(userId, 'risk-warnings', [
      { role: 'system', content: `${systemJsonPrompt} 你需要识别大学生学习计划中的风险，只输出明确可执行的提醒。` },
      {
        role: 'user',
        content:
          `今天：${new Date().toISOString()}\n日志：${JSON.stringify(dto.logs)}\n任务：${JSON.stringify(dto.tasks)}\n请生成 JSON：{"warnings":[{"title":"","description":"","level":"low|medium|high","category":"deadline|gap|completionRate|logFrequency|repeatedProblem"}]}。没有风险返回 {"warnings":[]}`,
      },
    ]);
  }

  generateFlashCards(userId: string, dto: FlashCardsDto) {
    return this.callJson(userId, 'flash-cards', [
      { role: 'system', content: `${systemJsonPrompt} 你需要根据学习日志生成问答闪卡，帮助巩固知识点。` },
      {
        role: 'user',
        content: `日志：${JSON.stringify(dto.logs)}\n生成 ${dto.count ?? 5} 张闪卡，JSON：{"cards":[{"question":"","answer":"","courseName":"","hint":""}]}`,
      },
    ]);
  }

  async chat(userId: string, dto: ChatDto) {
    const messages = this.buildChatMessages(dto);
    return {
      content: await this.callText(userId, 'chat', messages, dto),
    };
  }

  async streamChat(
    userId: string,
    dto: ChatDto,
    onChunk: (chunk: string) => void,
  ) {
    const runtime = this.getRuntime(dto.provider, dto.model);
    await this.assertDailyLimit(userId);
    const messages = this.buildChatMessages(dto);
    const startedAt = Date.now();
    let responseChars = 0;

    try {
      const response = await fetch(this.urlFor(runtime), {
        method: 'POST',
        headers: this.headersFor(runtime),
        body: JSON.stringify(this.payloadFor(runtime, messages, dto, true)),
      });
      if (!response.ok || !response.body) {
        throw new Error(await response.text());
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';
        for (const raw of lines) {
          const data = raw.trim().startsWith('data:')
            ? raw.trim().slice(5).trim()
            : '';
          if (!data || data === '[DONE]') continue;
          const chunk = this.extractStreamChunk(data);
          if (chunk) {
            responseChars += chunk.length;
            onChunk(chunk);
          }
        }
      }

      await this.logUsage(userId, 'chat/stream', runtime, true, startedAt, this.promptLength(messages), responseChars);
    } catch (error) {
      await this.logUsage(userId, 'chat/stream', runtime, false, startedAt, this.promptLength(messages), responseChars, error);
      throw error;
    }
  }

  private async callJson(userId: string, endpoint: string, messages: Record<string, unknown>[]) {
    const content = await this.callText(userId, endpoint, messages, {});
    return this.decodeJsonObject(content);
  }

  private async callText(
    userId: string,
    endpoint: string,
    messages: Record<string, unknown>[],
    dto: Partial<ChatDto>,
  ) {
    const runtime = this.getRuntime(dto.provider, dto.model);
    await this.assertDailyLimit(userId);
    const startedAt = Date.now();
    let content = '';

    try {
      const response = await fetch(this.urlFor(runtime), {
        method: 'POST',
        headers: this.headersFor(runtime),
        body: JSON.stringify(this.payloadFor(runtime, messages, dto, false)),
      });
      const body = await response.text();
      if (!response.ok) throw new Error(body);
      const decoded = JSON.parse(body);
      content = decoded?.choices?.[0]?.message?.content?.trim();
      if (!content) throw new Error('AI 返回空内容');
      await this.logUsage(userId, endpoint, runtime, true, startedAt, this.promptLength(messages), content.length);
      return content;
    } catch (error) {
      await this.logUsage(userId, endpoint, runtime, false, startedAt, this.promptLength(messages), content.length, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  private buildChatMessages(dto: ChatDto) {
    if (dto.messages?.length) {
      return [...dto.messages, { role: 'user', content: dto.input }];
    }
    const context = dto.context?.length ? `上下文：\n${dto.context.join('\n')}\n\n` : '';
    return [
      { role: 'system', content: dto.purpose === 'note' ? '你是 StudyTrace 的学习笔记整理助手。' : assistantSystemPrompt },
      { role: 'user', content: `${context}用户输入：${dto.input}` },
    ];
  }

  private payloadFor(
    runtime: ModelRuntime,
    messages: Record<string, unknown>[],
    dto: Partial<ChatDto>,
    stream: boolean,
  ) {
    return {
      model: runtime.model,
      messages,
      temperature: Number(dto.options?.temperature ?? 0.7),
      max_tokens: Number(dto.options?.maxTokens ?? 1800),
      top_p: Number(dto.options?.topP ?? 0.7),
      stream,
      ...(dto.thinkingEnabled ? { thinking: { type: 'enabled' } } : {}),
    };
  }

  private getRuntime(provider?: string, model?: string): ModelRuntime {
    const selected = (provider ?? this.config.get('AI_PROVIDER') ?? 'blueheart') as Provider;
    if (selected === 'deepseek') {
      return {
        provider: 'deepseek',
        apiKey: this.required('DEEPSEEK_API_KEY'),
        baseUrl: this.config.get('DEEPSEEK_BASE_URL') ?? 'https://api.deepseek.com/chat/completions',
        model: model ?? this.config.get('DEEPSEEK_MODEL') ?? 'deepseek-chat',
      };
    }
    return {
      provider: 'blueheart',
      apiKey: this.required('BLUEHEART_API_KEY'),
      baseUrl: this.config.get('BLUEHEART_BASE_URL') ?? 'https://api-ai.vivo.com.cn/v1/chat/completions',
      model: model ?? this.config.get('BLUEHEART_MODEL') ?? 'Volc-DeepSeek-V3.2',
    };
  }

  private required(key: string) {
    const value = this.config.get<string>(key);
    if (!value) throw new ServiceUnavailableException(`${key} 未配置`);
    return value;
  }

  private urlFor(runtime: ModelRuntime) {
    if (runtime.provider !== 'blueheart') return runtime.baseUrl;
    const url = new URL(runtime.baseUrl);
    url.searchParams.set('requestId', randomUUID());
    return url.toString();
  }

  private headersFor(runtime: ModelRuntime) {
    return {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${runtime.apiKey}`,
    };
  }

  private decodeJsonObject(raw: string) {
    try {
      return JSON.parse(raw);
    } catch (_) {
      const start = raw.indexOf('{');
      const end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) {
        return JSON.parse(raw.slice(start, end + 1));
      }
      throw new ServiceUnavailableException('AI 返回格式异常');
    }
  }

  private extractStreamChunk(data: string) {
    try {
      const decoded = JSON.parse(data);
      return decoded?.choices?.[0]?.delta?.content ?? '';
    } catch (_) {
      return '';
    }
  }

  private async assertDailyLimit(userId: string) {
    const limit = Number(this.config.get('AI_DAILY_LIMIT') ?? 50);
    const used = await this.prisma.aiUsageLog.count({
      where: {
        userId,
        createdAt: { gte: startOfToday() },
      },
    });
    if (used >= limit) {
      throw new HttpException('今日 AI 使用次数已达上限', HttpStatus.TOO_MANY_REQUESTS);
    }
  }

  private async logUsage(
    userId: string,
    endpoint: string,
    runtime: ModelRuntime,
    success: boolean,
    startedAt: number,
    promptChars: number,
    responseChars: number,
    error?: unknown,
  ) {
    await this.prisma.aiUsageLog.create({
      data: {
        userId,
        endpoint,
        provider: runtime.provider,
        model: runtime.model,
        success,
        durationMs: Date.now() - startedAt,
        promptChars,
        responseChars,
        errorMessage: error ? this.errorMessage(error) : null,
      },
    });
  }

  private promptLength(messages: Record<string, unknown>[]) {
    return JSON.stringify(messages).length;
  }

  private errorMessage(error: unknown) {
    if (error instanceof Error) return error.message;
    return String(error);
  }
}
