import {
  HttpException,
  HttpStatus,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, randomUUID } from 'crypto';
import { startOfToday } from '../../common/date-range';
import { PrismaService } from '../../prisma/prisma.service';
import {
  ChatDto,
  EmbeddingIndexDto,
  EmbeddingSearchDto,
  FlashCardGradeDto,
  FlashCardsDto,
  ImageTaskQueryDto,
  ImageTaskSubmitDto,
  LearningLoopDto,
  OcrDto,
  PoiSearchDto,
  QueryRewriteDto,
  RerankDto,
  ReverseGeocodeDto,
  RewriteDto,
  RiskWarningsDto,
  SpeechTranscribeDto,
  TextInputDto,
  TranslateDto,
  VideoTaskQueryDto,
  VideoTaskSubmitDto,
  WeeklyAnalysisDto,
  WeeklyPlanDto,
} from './dto/ai-common.dto';
import {
  assistantJsonPrompt,
  assistantSystemPrompt,
  noteMarkdownPrompt,
  systemJsonPrompt,
} from './ai-prompts';
import { vivoCapabilityLabel } from './vivo-capabilities';
import { VivoGatewayService } from './vivo-gateway.service';

type ModelRuntime = {
  provider: 'blueheart';
  apiKey: string;
  baseUrl: string;
  model: string;
};

@Injectable()
export class AiService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly vivo: VivoGatewayService,
  ) {}

  generateStudyLog(userId: string, dto: TextInputDto) {
    return this.callJson(userId, 'study-log', [
      { role: 'system', content: `${systemJsonPrompt} 你需要把大学生的自然语言学习描述整理成结构化学习日志。` },
      { role: 'user', content: `请根据输入生成 JSON：{"courseName":"","content":"","problems":"","thoughts":"","nextPlan":""}\n输入：${dto.input}` },
    ], dto);
  }

  generateTaskPlan(userId: string, dto: TextInputDto) {
    return this.callJson(userId, 'task-plan', [
      { role: 'system', content: `${systemJsonPrompt} 你需要把复杂学习任务拆成可执行计划。` },
      {
        role: 'user',
        content:
          `今天：${new Date().toISOString()}\n请生成 JSON：{"mainTitle":"","taskType":"classHomework|paperReading|programmingHomework|labReport|projectDev|examReview|readingNotes|other","courseName":"","deadline":"ISO8601","difficulty":"较轻松|中等|困难","subTasks":[""],"plannedSubTasks":[{"title":"","deadline":"ISO8601","note":""}],"schedule":""}\n输入：${dto.input}`,
      },
    ], dto);
  }

  generateWeeklyAnalysis(userId: string, dto: WeeklyAnalysisDto) {
    return this.callJson(userId, 'weekly-analysis', [
      { role: 'system', content: `${systemJsonPrompt} 你需要根据学习日志和任务数据生成分析型学习周报。` },
      {
        role: 'user',
        content:
          `分析周期：${dto.startDate} 至 ${dto.endDate}\n学习日志：${JSON.stringify(dto.logs)}\n任务：${JSON.stringify(dto.tasks)}\n请生成 JSON：{"mainTopics":"","courseDistribution":"","frequentProblems":"","completedTasks":"","riskTasks":"","statusEvaluation":"","nextWeekPriority":""}`,
      },
    ], dto);
  }

  generateRiskWarnings(userId: string, dto: RiskWarningsDto) {
    return this.callJson(userId, 'risk-warnings', [
      { role: 'system', content: `${systemJsonPrompt} 你需要识别大学生学习计划中的风险，只输出明确可执行的提醒。` },
      {
        role: 'user',
        content:
          `今天：${new Date().toISOString()}\n日志：${JSON.stringify(dto.logs)}\n任务：${JSON.stringify(dto.tasks)}\n请生成 JSON：{"warnings":[{"title":"","description":"","level":"low|medium|high","category":"deadline|gap|completionRate|logFrequency|repeatedProblem"}]}。没有风险返回 {"warnings":[]}`,
      },
    ], dto);
  }

  generateFlashCards(userId: string, dto: FlashCardsDto) {
    return this.callJson(userId, 'flash-cards', [
      { role: 'system', content: `${systemJsonPrompt} 你需要根据学习日志生成问答闪卡，帮助巩固知识点。` },
      {
        role: 'user',
        content: `日志：${JSON.stringify(dto.logs)}\n生成 ${dto.count ?? 5} 张闪卡，JSON：{"cards":[{"question":"","answer":"","courseName":"","hint":""}]}`,
      },
    ], dto);
  }

  generateWeeklyPlan(userId: string, dto: WeeklyPlanDto) {
    const days = Math.min(Math.max(Number(dto.days ?? 7), 1), 14);
    return this.callJson(userId, 'weekly-plan', [
      { role: 'system', content: `${systemJsonPrompt} 你需要为大学生生成未来几天的学习计划。` },
      {
        role: 'user',
        content:
          `今天：${new Date().toISOString()}\n待办任务：${JSON.stringify(dto.tasks ?? [])}\n最近日志：${JSON.stringify(dto.logs ?? [])}\n可用课程：${JSON.stringify(dto.courses ?? [])}\n` +
          `请生成未来 ${days} 天的学习计划，每天 2-4 个任务，兼顾待办任务与日志中提到的下一步计划。` +
          '输出 JSON：{"plans":[{"date":"YYYY-MM-DD","tasks":[{"title":"任务名","courseName":"课程名","note":"简短说明"}]}]}',
      },
    ], dto);
  }

  async generateLearningLoop(userId: string, dto: LearningLoopDto) {
    const sourceKind = dto.sourceKind ?? 'manual';
    const target = dto.target ?? 'all';
    const context = dto.context?.length ? `App 上下文：\n${dto.context.join('\n')}\n\n` : '';
    const rawSourceText = (dto.sourceText ?? '').trim();
    const prepared =
      dto.imageBase64 && !rawSourceText
        ? await this.dtoWithOcrImageSummary({
            input: '请识别这张学习材料，并整理成学习计划。',
            imageBase64: dto.imageBase64,
          })
        : null;
    const sourceText = this.clipText(
      (rawSourceText || prepared?.input || '').trim(),
      6000,
    );
    const imageHint =
      dto.imageBase64 && rawSourceText
        ? '输入来自图片 OCR，必要时把它视作课堂材料、题目、课件或课程通知。'
        : '';

    const capabilities = dto.imageBase64
      ? '["通用OCR","蓝心多模态理解","蓝心对话"]'
      : '["蓝心对话"]';
    const outputSchema =
      target === 'task'
        ? '请输出 JSON：{"loopSchemaVersion":"final-demo-v2","summary":"","courseName":"","concepts":[],"sourceEvidence":[{"type":"reflection|history|flashcard|task","summary":"","confidence":0.0}],"reflectionAnalysis":{"summary":"","blockers":[""],"emotion":{"label":"","intensity":0.0},"mastery":{"知识点":0.0},"forgettingRisk":"low|medium|high","nextActions":[""],"explanation":""},"actionCards":[{"title":"","steps":[""],"deadline":"ISO8601","reason":"","priority":"high|medium|low","durationMinutes":25,"successCriteria":"","source":""}],"reviewCards":[{"date":"YYYY-MM-DD","title":"","minutes":25,"reason":""}],"taskDrafts":[{"title":"","type":"classHomework|paperReading|programmingHomework|labReport|projectDev|examReview|readingNotes|other","deadline":"ISO8601","note":"","subTasks":[{"title":"","deadline":"ISO8601","note":""}]}],"noteDraft":{"title":"","content":"","blocks":[]},"flashcards":[],"reviewPlan":[{"date":"YYYY-MM-DD","title":"","minutes":25,"reason":""}],"suggestedActions":[{"type":"task.add_direct","title":"","content":"","sourceText":""}],"vivoCapabilitiesUsed":'
        : '请输出 JSON：{"loopSchemaVersion":"final-demo-v2","summary":"","courseName":"","concepts":[""],"sourceEvidence":[{"type":"reflection|history|flashcard|task","summary":"","confidence":0.0}],"reflectionAnalysis":{"summary":"","blockers":[""],"emotion":{"label":"","intensity":0.0},"mastery":{"知识点":0.0},"forgettingRisk":"low|medium|high","nextActions":[""],"explanation":""},"actionCards":[{"title":"","steps":[""],"deadline":"ISO8601","reason":"","priority":"high|medium|low","durationMinutes":25,"successCriteria":"","source":""}],"reviewCards":[{"date":"YYYY-MM-DD","title":"","minutes":25,"reason":""}],"taskDrafts":[{"title":"","type":"classHomework|paperReading|programmingHomework|labReport|projectDev|examReview|readingNotes|other","deadline":"ISO8601","note":"","subTasks":[{"title":"","deadline":"ISO8601","note":""}]}],"noteDraft":{"title":"","content":"","blocks":[{"type":"heading|text|bullet|todo|code|divider","content":""}]},"flashcards":[{"question":"","answer":"","hint":"","courseName":""}],"reviewPlan":[{"date":"YYYY-MM-DD","title":"","minutes":25,"reason":""}],"suggestedActions":[{"type":"log.create|task.add_direct|note.save|flashcard.create_batch","title":"","content":"","sourceText":""}],"vivoCapabilitiesUsed":';
    const outputConstraint =
      target === 'task'
        ? '约束：loopSchemaVersion 固定为 final-demo-v2；sourceEvidence 最多 3 条，说明建议依据；reflectionAnalysis 必须解释难点、情绪、掌握度、遗忘风险和原因；actionCards 最多 3 条，必须是明天或今天可执行的小行动，每条要有 priority、durationMinutes、successCriteria 和 source；taskDrafts 最多 2 个，每个 subTasks 最多 3 个；reviewPlan 和 reviewCards 最多 4 条且保持一致；noteDraft.blocks 和 flashcards 必须返回空数组；如果信息不足，生成 2-4 个今天可执行的专注块。'
        : '约束：loopSchemaVersion 固定为 final-demo-v2；sourceEvidence 最多 3 条，说明建议依据；reflectionAnalysis 必须解释难点、情绪、掌握度、遗忘风险和原因；actionCards 最多 3 条，必须是明天或今天可执行的小行动，每条要有 priority、durationMinutes、successCriteria 和 source；taskDrafts 最多 3 个，每个 subTasks 最多 4 个；flashcards 最多 6 张；reviewPlan 和 reviewCards 最多 4 条且保持一致；noteDraft 必须像 Notion 块笔记：title 简短，content 用 Markdown，小标题/短段落/列表/待办分明；noteDraft.blocks 优先返回 6-14 个块，type 只用 heading/text/bullet/todo/code/divider，不要把流程文字改成图片或图解提示词；如果材料信息不足，仍给出保守、可编辑的草稿。';
    const prompt =
      `${context}来源类型：${sourceKind}\n生成目标：${target}\n${imageHint}\n今天：${new Date().toISOString()}\n学习材料：\n${sourceText}\n\n` +
      outputSchema +
      `${capabilities}}\n` +
      outputConstraint;
    const userMessageContent = dto.imageBase64
      ? [
          { type: 'text', text: prompt },
          {
            type: 'image_url',
            image_url: { url: `data:image/jpeg;base64,${dto.imageBase64}` },
          },
        ]
      : prompt;

    const messages = [
      {
        role: 'system',
        content:
          `${systemJsonPrompt} 你是 StudyTrace 的 AI 学习复盘与防遗忘规划助手。你要把学习材料转成结构化诊断、今日/明日行动卡、复习计划和可执行落地内容，字段必须稳定，内容要能直接写入学习任务、日志、笔记和闪卡。\n${noteMarkdownPrompt}`,
      },
      {
        role: 'user',
        content: userMessageContent,
      },
    ];
    const startedAt = Date.now();
    const requestId = randomUUID();
    try {
      const result = await this.callJson(userId, 'learning-loop', messages, dto);
      return {
        ...result,
        capabilityTraces: [
          this.vivo.trace(
            dto.imageBase64 ? 'BlueLM vision learning loop' : 'BlueLM learning loop',
            '/v1/chat/completions',
            requestId,
            startedAt,
            true,
            { model: this.config.get('BLUEHEART_MODEL') ?? 'Doubao-Seed-2.0-mini' },
          ),
        ],
      };
    } catch (error) {
      if (!dto.imageBase64) throw error;
      const fallbackStarted = Date.now();
      const fallbackResult = await this.callJson(userId, 'learning-loop/ocr-fallback', [
        messages[0],
        { role: 'user', content: prompt },
      ], dto);
      return {
        ...fallbackResult,
        capabilityTraces: [
          this.vivo.trace(
            'BlueLM vision learning loop',
            '/v1/chat/completions',
            requestId,
            startedAt,
            false,
            {
              model: this.config.get('BLUEHEART_MODEL') ?? 'Doubao-Seed-2.0-mini',
              fallback: 'OCR text only',
              detail: this.errorMessage(error),
            },
          ),
          this.vivo.trace(
            'BlueLM OCR fallback learning loop',
            '/v1/chat/completions',
            randomUUID(),
            fallbackStarted,
            true,
            { model: this.config.get('BLUEHEART_MODEL') ?? 'Doubao-Seed-2.0-mini' },
          ),
        ],
      };
    }
  }

  async rewrite(userId: string, dto: RewriteDto) {
    const source = dto.text.trim();
    if (!source) return { text: '' };
    const text = await this.callText(userId, 'rewrite', [
      {
        role: 'system',
        content:
          '你是 StudyTrace 的学习笔记编辑助手。直接返回改写后的正文，不要有开场白、解释或引号。',
      },
      { role: 'user', content: `${this.rewritePrompt(dto.intent)}\n\n原文：\n${source}` },
    ], dto);
    return { text };
  }

  gradeFlashcard(userId: string, dto: FlashCardGradeDto) {
    return this.callJson(userId, 'grade-flashcard', [
      {
        role: 'system',
        content:
          `${systemJsonPrompt} 你是 StudyTrace 的知识闪卡判分助手。严格按参考答案判分，不要放水。`,
      },
      {
        role: 'user',
        content:
          `题目：${dto.question}\n参考答案：${dto.correctAnswer}\n用户回答：${dto.userAnswer}\n${dto.courseName ? `课程：${dto.courseName}\n` : ''}` +
          '请给用户的回答打分并给出反馈，输出 JSON：{"score":1-5,"feedback":"用 1-2 句中文给出反馈"}',
      },
    ], dto);
  }

  async ocr(userId: string, dto: OcrDto) {
    const runtime = this.getBlueHeartAbilityRuntime('general-ocr');
    await this.assertDailyLimit(userId);
    const startedAt = Date.now();
    const requestId = randomUUID();
    let text = '';

    try {
      text = await this.recognizeImageText(dto.imageBase64, runtime);
      await this.logUsage(userId, 'ocr', runtime, true, startedAt, dto.imageBase64.length, text.length);
      return {
        text,
        capabilityTraces: [
          this.vivo.trace('General OCR', '/ocr/general_recognition', requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'ocr', runtime, false, startedAt, dto.imageBase64.length, text.length, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  async queryRewrite(userId: string, dto: QueryRewriteDto) {
    const query = dto.query.trim();
    if (!query || query.length > 50) return { query };
    const runtime = this.getBlueHeartAbilityRuntime('query-rewrite');
    await this.assertDailyLimit(userId);
    const startedAt = Date.now();
    const requestId = randomUUID();
    let rewritten = query;

    try {
      const response = await fetch(
        `https://api-ai.vivo.com.cn/query_rewrite_base?requestId=${requestId}`,
        {
          method: 'POST',
          headers: this.headersFor(runtime),
          body: JSON.stringify({
            prompts: [['', '', '', '', '', ''], [query]],
          }),
        },
      );
      const raw = await response.text();
      if (!response.ok) throw new Error(raw);
      const decoded = JSON.parse(raw);
      if (decoded?.code === 0 && Array.isArray(decoded?.result) && decoded.result[0]) {
        rewritten = String(decoded.result[0]).trim() || query;
      }
      await this.logUsage(userId, 'query-rewrite', runtime, true, startedAt, query.length, rewritten.length);
      return {
        query: rewritten,
        capabilityTraces: [
          this.vivo.trace('Query rewrite', '/query_rewrite_base', requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'query-rewrite', runtime, false, startedAt, query.length, rewritten.length, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  async rerank(userId: string, dto: RerankDto) {
    const runtime = this.getBlueHeartAbilityRuntime('bge-reranker-large');
    const query = this.clipText(dto.query, 500);
    const sentences = dto.sentences.slice(0, 20).map((item) => this.clipText(item, 500));
    await this.assertDailyLimit(userId);
    const startedAt = Date.now();
    const requestId = randomUUID();

    try {
      const response = await fetch(
        `https://api-ai.vivo.com.cn/rerank?requestId=${requestId}`,
        {
          method: 'POST',
          headers: this.headersFor(runtime),
          body: JSON.stringify({
            model_name: 'bge-reranker-large',
            query,
            sentences,
          }),
        },
      );
      const raw = await response.text();
      if (!response.ok) throw new Error(raw);
      const decoded = JSON.parse(raw);
      const scores = Array.isArray(decoded?.data) ? decoded.data : [];
      await this.logUsage(userId, 'rerank', runtime, true, startedAt, query.length + sentences.join('').length, scores.length);
      return {
        scores,
        capabilityTraces: [
          this.vivo.trace('Text rerank', '/rerank', requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'rerank', runtime, false, startedAt, query.length + sentences.join('').length, 0, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  async translate(userId: string, dto: TranslateDto) {
    const text = this.clipText(dto.text, 1200);
    if (!text) return { text: '', from: dto.from ?? 'auto', to: dto.to ?? 'en', capabilityTraces: [] };
    const runtime = this.getBlueHeartAbilityRuntime('text-translation');
    const requestId = randomUUID();
    const startedAt = Date.now();
    const endpoint = this.config.get<string>('VIVO_TRANSLATE_PATH') ?? '/translation/query/self';
    await this.assertDailyLimit(userId);
    try {
      const decoded = await this.vivo.postJson(endpoint, {
        text,
        source_lang: dto.from ?? 'auto',
        target_lang: dto.to ?? 'en',
        app_name: this.config.get<string>('VIVO_TRANSLATE_APP_NAME') ?? 'studytrace',
      });
      const translated = this.extractTextResult(decoded);
      if (!translated) throw new Error('empty translation response');
      await this.logUsage(userId, 'translate', runtime, true, startedAt, text.length, translated.length);
      return {
        text: translated,
        from: dto.from ?? 'auto',
        to: dto.to ?? 'en',
        capabilityTraces: [
          this.vivo.trace('Text translation', endpoint, requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'translate', runtime, false, startedAt, text.length, 0, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  async submitImageTask(userId: string, dto: ImageTaskSubmitDto) {
    const imageModel = this.config.get<string>('VIVO_IMAGE_MODEL') ?? 'Doubao-Seedream-5.0-lite';
    const runtime = this.getBlueHeartAbilityRuntime(imageModel);
    const requestId = randomUUID();
    const startedAt = Date.now();
    const endpoint = this.config.get<string>('VIVO_IMAGE_GENERATION_PATH') ?? '/api/v1/image_generation';
    await this.assertDailyLimit(userId);
    try {
      const decoded = await this.vivo.postJson(
        endpoint,
        {
          model: imageModel,
          prompt: dto.prompt.trim(),
          ...(dto.initImageBase64
            ? {
                image: dto.initImageBase64.startsWith('data:')
                  ? dto.initImageBase64
                  : `data:image/png;base64,${dto.initImageBase64}`,
              }
            : {}),
          parameters: this.imageGenerationParameters(),
        },
        this.vivoTaskQuery(requestId),
      );
      const result = this.vivoData(decoded) as any;
      const imagesUrl = this.extractImageUrls(result);
      if (!imagesUrl.length) throw new Error('image generation returned no images');
      const taskId = String((decoded as any)?.trace_id ?? result?.provider_request_id ?? requestId);
      await this.logUsage(userId, 'image-generation/submit', runtime, true, startedAt, dto.prompt.length, imagesUrl.join('').length);
      return {
        taskId,
        status: 'succeeded',
        imagesUrl,
        auditStatus: result?.finish_reason,
        capabilityTraces: [
          this.vivo.trace('Image generation', endpoint, requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'image-generation/submit', runtime, false, startedAt, dto.prompt.length, 0, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  async queryImageTask(userId: string, dto: ImageTaskQueryDto) {
    const runtime = this.getBlueHeartAbilityRuntime('image-generation');
    const requestId = randomUUID();
    const startedAt = Date.now();
    const endpoint = this.config.get<string>('VIVO_IMAGE_QUERY_PATH');
    await this.assertDailyLimit(userId);
    if (!endpoint || dto.taskId.startsWith('http')) {
      const imagesUrl = dto.taskId.startsWith('http') ? [dto.taskId] : [];
      return {
        taskId: dto.taskId,
        status: imagesUrl.length ? 'succeeded' : 'not_queryable',
        imagesUrl,
        capabilityTraces: [
          this.vivo.trace('Image generation status', 'sync:image_generation', requestId, startedAt, true, {
            model: runtime.model,
            detail: 'Latest image_generation API returns images synchronously.',
          }),
        ],
      };
    }
    try {
      const decoded = await this.vivo.getJson(endpoint, { task_id: dto.taskId });
      const result = this.vivoData(decoded) as any;
      await this.logUsage(userId, 'image-generation/query', runtime, true, startedAt, dto.taskId.length, JSON.stringify(decoded).length);
      return {
        taskId: dto.taskId,
        status: result?.status ?? 'processing',
        imagesUrl: this.extractImageUrls(result),
        auditStatus: result?.audit_status ?? result?.auditStatus,
        capabilityTraces: [
          this.vivo.trace('Image generation status', endpoint, requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'image-generation/query', runtime, false, startedAt, dto.taskId.length, 0, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  async submitVideoTask(userId: string, dto: VideoTaskSubmitDto) {
    const runtime = this.getBlueHeartAbilityRuntime(
      this.config.get<string>('VIVO_VIDEO_MODEL') ?? 'Doubao-Seedance-1.0-pro',
    );
    const requestId = randomUUID();
    const startedAt = Date.now();
    const endpoint = this.config.get<string>('VIVO_VIDEO_SUBMIT_PATH') ?? '/api/v1/submit_task';
    const prompt = dto.prompt.trim();
    await this.assertDailyLimit(userId);
    try {
      const decoded = await this.vivo.postJson(endpoint, {
        model: dto.model ?? runtime.model,
        content: this.videoGenerationContent(dto, prompt),
      }, this.vivoTaskQuery(requestId));
      const result = this.vivoData(decoded) as any;
      const taskId = String(result?.id ?? result?.task_id ?? result?.taskId ?? '');
      if (!taskId) throw new Error('video task id missing');
      await this.logUsage(userId, 'video-generation/submit', runtime, true, startedAt, prompt.length, taskId.length);
      return {
        taskId,
        status: result?.status ?? 'submitted',
        capabilityTraces: [
          this.vivo.trace('Video generation', endpoint, requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'video-generation/submit', runtime, false, startedAt, prompt.length, 0, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  async queryVideoTask(userId: string, dto: VideoTaskQueryDto) {
    const runtime = this.getBlueHeartAbilityRuntime('video-generation');
    const requestId = randomUUID();
    const startedAt = Date.now();
    const endpoint = this.config.get<string>('VIVO_VIDEO_QUERY_PATH') ?? '/api/v1/query_task';
    await this.assertDailyLimit(userId);
    try {
      const decoded = await this.vivo.getJson(endpoint, {
        task_id: dto.taskId,
        ...this.vivoTaskQuery(requestId),
      });
      const result = this.vivoData(decoded) as any;
      const videosUrl = this.extractStringList(
        result?.videos_url ??
          result?.videosUrl ??
          result?.video_url ??
          result?.videoUrl ??
          result?.content?.video_url ??
          result?.content?.videoUrl ??
          result?.url,
      );
      await this.logUsage(userId, 'video-generation/query', runtime, true, startedAt, dto.taskId.length, JSON.stringify(decoded).length);
      return {
        taskId: dto.taskId,
        status: result?.status ?? 'processing',
        videosUrl,
        coverUrl: result?.cover_url ?? result?.coverUrl,
        auditStatus: result?.audit_status ?? result?.auditStatus,
        capabilityTraces: [
          this.vivo.trace('Video generation status', endpoint, requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'video-generation/query', runtime, false, startedAt, dto.taskId.length, 0, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  async transcribeSpeech(userId: string, dto: SpeechTranscribeDto) {
    const runtime = this.getBlueHeartAbilityRuntime('long-audio-transcription');
    const requestId = randomUUID();
    const startedAt = Date.now();
    await this.assertDailyLimit(userId);
    try {
      const text = await this.transcribeByLasr(userId, dto, requestId);
      if (!text) throw new Error('empty ASR response');
      await this.logUsage(userId, 'speech-transcribe', runtime, true, startedAt, dto.audioBase64.length, text.length);
      return {
        text,
        capabilityTraces: [
          this.vivo.trace('Long audio transcription', '/lasr/create → /lasr/result', requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      const fallbackEndpoint = this.config.get<string>('VIVO_ASR_ENDPOINT');
      if (!fallbackEndpoint) {
        await this.logUsage(userId, 'speech-transcribe', runtime, false, startedAt, dto.audioBase64.length, 0, error);
        throw new ServiceUnavailableException(this.errorMessage(error));
      }
      try {
        const decoded = await this.vivo.optionalPostJson('VIVO_ASR_ENDPOINT', {
          audio: dto.audioBase64,
          mime_type: dto.mimeType ?? 'audio/m4a',
          mode: dto.mode ?? 'short',
          engine_id: this.config.get<string>('VIVO_ASR_ENGINE_ID') ?? '',
          request_id: requestId,
        });
        const text = this.extractTextResult(decoded);
        if (!text) throw new Error('empty ASR fallback response');
        await this.logUsage(userId, 'speech-transcribe', runtime, true, startedAt, dto.audioBase64.length, text.length);
        return {
          text,
          capabilityTraces: [
            this.vivo.trace('Long audio transcription', '/lasr/create → /lasr/result', requestId, startedAt, false, {
              model: runtime.model,
              fallback: 'VIVO_ASR_ENDPOINT',
              detail: this.errorMessage(error),
            }),
            this.vivo.trace('Cloud speech transcription', 'VIVO_ASR_ENDPOINT', randomUUID(), Date.now(), true, {
              model: this.config.get<string>('VIVO_ASR_ENGINE_ID') ?? '',
            }),
          ],
        };
      } catch (fallbackError) {
        await this.logUsage(userId, 'speech-transcribe', runtime, false, startedAt, dto.audioBase64.length, 0, fallbackError);
        throw new ServiceUnavailableException(this.errorMessage(fallbackError));
      }
    }
  }

  async indexMemory(userId: string, dto: EmbeddingIndexDto) {
    const db = this.prisma as any;
    const indexed: string[] = [];
    for (const item of dto.items.slice(0, 50)) {
      const sourceType = String(item.sourceType ?? '').trim();
      const sourceId = String(item.sourceId ?? '').trim();
      const title = String(item.title ?? '').trim();
      const content = this.clipText(String(item.content ?? ''), 4000);
      if (!sourceType || !sourceId || !content) continue;
      const embedding = await this.embeddingVector(userId, content);
      await db.memoryChunk.upsert({
        where: { id: `${userId}_${sourceType}_${sourceId}` },
        create: {
          id: `${userId}_${sourceType}_${sourceId}`,
          userId,
          sourceType,
          sourceId,
          title: title || sourceType,
          content,
          embeddingJson: embedding.vector,
          metadataJson: item.metadata ?? null,
        },
        update: {
          title: title || sourceType,
          content,
          embeddingJson: embedding.vector,
          metadataJson: item.metadata ?? null,
        },
      });
      indexed.push(sourceId);
    }
    return { indexedCount: indexed.length, indexed };
  }

  async searchMemory(userId: string, dto: EmbeddingSearchDto) {
    const queryEmbedding = await this.embeddingVector(userId, dto.query);
    const db = this.prisma as any;
    const chunks = await db.memoryChunk.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
      take: 300,
    });
    const hits = chunks
      .map((chunk) => ({
        sourceType: chunk.sourceType,
        sourceId: chunk.sourceId,
        title: chunk.title,
        content: chunk.content,
        score: this.cosine(queryEmbedding.vector, this.numberArray(chunk.embeddingJson)),
      }))
      .sort((a, b) => b.score - a.score)
      .slice(0, dto.limit ?? 8);
    return { hits, capabilityTraces: queryEmbedding.capabilityTraces };
  }

  async poiSearch(userId: string, dto: PoiSearchDto) {
    const runtime = this.getBlueHeartAbilityRuntime('poi-search');
    const requestId = randomUUID();
    const startedAt = Date.now();
    const endpoint = this.config.get<string>('VIVO_POI_SEARCH_ENDPOINT') ?? '/search/geo';
    await this.assertDailyLimit(userId);
    try {
      const decoded = await this.vivo.getJson(endpoint, {
        keywords: dto.query.trim(),
        city: dto.city ?? '',
        page_num: '1',
        page_size: '10',
        requestId,
      });
      await this.logUsage(userId, 'poi-search', runtime, true, startedAt, dto.query.length, JSON.stringify(decoded).length);
      return {
        result: decoded,
        capabilityTraces: [
          this.vivo.trace('POI search', endpoint, requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'poi-search', runtime, false, startedAt, dto.query.length, 0, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  async reverseGeocode(userId: string, dto: ReverseGeocodeDto) {
    return this.poiCall(userId, 'reverse-geocode', { location: dto.location.trim() });
  }

  async capabilityBadges(userId: string) {
    const db = this.prisma as any;
    const [
      usageRows,
      activityRows,
      evidencePackageCount,
      challengeEvidenceCount,
      locationCount,
    ] = await Promise.all([
      this.prisma.aiUsageLog.groupBy({
        by: ['endpoint'],
        where: { userId, success: true },
        _count: { _all: true },
      }),
      this.prisma.studyActivity.groupBy({
        by: ['type'],
        where: { userId },
        _count: { _all: true },
      }),
      db.evidencePackage.count({ where: { userId } }),
      db.challengeEvidence.count({ where: { userId } }),
      db.locationCheckIn.count({ where: { userId } }),
    ]);
    const usage = new Map(usageRows.map((row) => [row.endpoint, row._count._all]));
    const activities = new Map(activityRows.map((row) => [row.type, row._count._all]));
    const usageTotal = Array.from(usage.values()).reduce((sum, value) => sum + value, 0);
    const activity = (type: string) => Number(activities.get(type) ?? 0);
    const endpointHas = (...parts: string[]) =>
      Array.from(usage.keys()).some((endpoint) =>
        parts.some((part) => endpoint.toLowerCase().includes(part.toLowerCase())),
      );
    const badge = (
      id: string,
      label: string,
      current: number,
      target: number,
      source: string,
    ) => ({
      id,
      label,
      current,
      target,
      source,
      unlocked: current >= target,
    });
    const providerLabel = (slug: string, fallback: string) =>
      vivoCapabilityLabel(slug, fallback);
    return {
      badges: [
        badge('llm', providerLabel('large-model', '大模型'), usageTotal, 1, 'AiUsageLog'),
        badge('ocr', providerLabel('general-ocr', 'OCR 识别'), endpointHas('ocr') ? Number(usage.get('ocr') ?? 1) : 0, 1, 'AiUsageLog'),
        badge('translation', providerLabel('text-translation', '双语动态'), activity('translatedMoment'), 1, 'StudyActivity'),
        badge('image', providerLabel('image-generation', '封面生成'), activity('imageGenerated') || (endpointHas('image') ? 1 : 0), 1, 'AiUsageLog + StudyActivity'),
        badge('video', providerLabel('video-generation', '视频生成'), endpointHas('video-generation') ? 1 : 0, 1, 'AiUsageLog'),
        badge('voice', '语音复盘', activity('voiceReview'), 1, 'StudyActivity'),
        badge('memory', providerLabel('text-embedding', '记忆检索'), endpointHas('embeddings') ? 1 : 0, 1, 'MemoryChunk'),
        badge('loop', 'AI 落地', activity('aiLoopApplied'), 1, 'StudyActivity'),
        badge('share', '学迹分享', activity('momentShared'), 1, 'StudyActivity'),
        badge('package', '资料包', evidencePackageCount, 1, 'EvidencePackage'),
        badge('challenge', '挑战记录', challengeEvidenceCount, 1, 'ChallengeEvidence'),
        badge('location', '地点打卡', locationCount, 1, 'LocationCheckIn'),
      ],
    };
  }

  async chat(userId: string, dto: ChatDto) {
    const messages = this.buildChatMessages(dto);
    const startedAt = Date.now();
    const requestId = randomUUID();
    try {
      const rawContent = await this.callText(userId, 'chat', messages, dto);
      return {
        content:
          dto.purpose === 'assistant_turn'
            ? JSON.stringify(this.normalizeAssistantTurn(rawContent, dto.input))
            : rawContent,
        capabilityTraces: [
          this.vivo.trace(
            dto.imageBase64 ? 'BlueLM vision chat' : 'BlueLM chat',
            '/v1/chat/completions',
            requestId,
            startedAt,
            true,
            { model: this.config.get('BLUEHEART_MODEL') ?? 'Doubao-Seed-2.0-mini' },
          ),
        ],
      };
    } catch (error) {
      if (!dto.imageBase64) throw error;
      const fallbackStarted = Date.now();
      const fallbackMessages = await this.buildChatMessagesWithOcrFallback(dto);
      return {
        content: await this.callText(
          userId,
          'chat/image-ocr-fallback',
          fallbackMessages,
          { ...dto, imageBase64: undefined },
        ),
        capabilityTraces: [
          this.vivo.trace(
            'BlueLM vision chat',
            '/v1/chat/completions',
            requestId,
            startedAt,
            false,
            { fallback: 'OCR text only', detail: this.errorMessage(error) },
          ),
          this.vivo.trace(
            'BlueLM OCR fallback chat',
            '/v1/chat/completions',
            randomUUID(),
            fallbackStarted,
            true,
            { model: this.config.get('BLUEHEART_MODEL') ?? 'Doubao-Seed-2.0-mini' },
          ),
        ],
      };
    }
  }

  async todayUsage(userId: string) {
    const limit = Number(this.config.get('AI_DAILY_LIMIT') ?? 50);
    const used = await this.prisma.aiUsageLog.count({
      where: {
        userId,
        createdAt: { gte: startOfToday() },
      },
    });
    return { used, limit, remaining: Math.max(0, limit - used) };
  }

  async streamChat(
    userId: string,
    dto: ChatDto,
    onChunk: (chunk: string) => void,
  ) {
    const runtime = this.getRuntime();
    await this.assertDailyLimit(userId);
    const preparedDto =
      dto.imageBase64 && this.shouldUseOcrForStream()
        ? await this.dtoWithOcrImageSummary(dto)
        : dto;
    const messages = this.buildChatMessages(preparedDto);
    const startedAt = Date.now();
    let responseChars = 0;

    try {
      const response = await fetch(this.urlFor(runtime), {
        method: 'POST',
        headers: this.headersFor(runtime),
        body: JSON.stringify(this.payloadFor(runtime, messages, preparedDto, true)),
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

  private async buildChatMessagesWithOcrFallback(dto: ChatDto) {
    const prepared = await this.dtoWithOcrImageSummary(dto);
    return this.buildChatMessages(prepared);
  }

  private async dtoWithOcrImageSummary(dto: ChatDto): Promise<ChatDto> {
    const runtime = this.getBlueHeartAbilityRuntime('general-ocr');
    const ocrText = await this.recognizeImageText(dto.imageBase64 ?? '', runtime);
    const input =
      `${dto.input}\n\n图片 OCR 结果：\n${ocrText || '未识别到文字，请按用户输入继续。'}`;
    return {
      ...dto,
      input,
      imageBase64: undefined,
    };
  }

  private shouldUseOcrForStream() {
    return (this.config.get<string>('BLUEHEART_STREAM_IMAGE_MODE') ?? 'ocr') !== 'vision';
  }

  private async callJson(
    userId: string,
    endpoint: string,
    messages: Record<string, unknown>[],
    dto: Partial<ChatDto> = {},
  ) {
    const content = await this.callText(userId, endpoint, messages, dto);
    return this.decodeJsonObject(content);
  }

  private async callText(
    userId: string,
    endpoint: string,
    messages: Record<string, unknown>[],
    dto: Partial<ChatDto>,
  ) {
    const runtime = this.getRuntime();
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
      this.assertChatResponseOk(decoded);
      content = this.extractChatContent(decoded);
      if (!content) throw new Error('AI 返回空内容');
      await this.logUsage(userId, endpoint, runtime, true, startedAt, this.promptLength(messages), content.length);
      return content;
    } catch (error) {
      await this.logUsage(userId, endpoint, runtime, false, startedAt, this.promptLength(messages), content.length, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  private extractChatContent(decoded: unknown) {
    const data = decoded as any;
    const message = data?.choices?.[0]?.message;
    const candidates = [
      message?.content,
      data?.output_text,
      data?.content,
      data?.data?.content,
      data?.result?.content,
      data?.result?.text,
      data?.text,
    ];
    for (const candidate of candidates) {
      const text = this.stringifyChatContent(candidate);
      if (text) return text;
    }
    return '';
  }

  private assertChatResponseOk(decoded: unknown) {
    const data = decoded as any;
    const message = data?.error?.message ?? data?.message;
    if (data?.error || (data?.code && !data?.choices)) {
      throw new Error(this.stringifyChatContent(message) || 'AI 服务返回错误');
    }
  }

  private stringifyChatContent(value: unknown): string {
    if (typeof value === 'string') return value.trim();
    if (Array.isArray(value)) {
      return value
        .map((item) => this.stringifyChatContent(
          typeof item === 'object' && item !== null
            ? ((item as any).text ?? (item as any).content ?? item)
            : item,
        ))
        .filter(Boolean)
        .join('\n')
        .trim();
    }
    if (value && typeof value === 'object') {
      const record = value as Record<string, unknown>;
      return this.stringifyChatContent(record.text ?? record.content);
    }
    return '';
  }

  private buildChatMessages(dto: ChatDto): Record<string, unknown>[] {
    const context = dto.context?.length ? `上下文：\n${dto.context.join('\n')}\n\n` : '';
    const systemContent =
      dto.purpose === 'assistant_turn'
        ? assistantJsonPrompt
        : dto.purpose === 'note'
          ? noteMarkdownPrompt
          : assistantSystemPrompt;
    const messages = [
      { role: 'system', content: systemContent },
      ...(dto.messages?.length ? dto.messages.filter((item) => item.role !== 'system') : []),
    ];
    messages.push({
      role: 'user',
      content: this.userContent(dto, context),
    });
    return messages;
  }

  private userContent(dto: ChatDto, context: string): unknown {
    const text = `${context}用户输入：${dto.input}`;
    if (!dto.imageBase64) return text;
    return [
      { type: 'text', text },
      {
        type: 'image_url',
        image_url: {
          url: `data:image/jpeg;base64,${dto.imageBase64}`,
        },
      },
    ];
  }

  private async embeddingVector(userId: string, text: string) {
    const runtime = this.getBlueHeartAbilityRuntime(
      this.config.get<string>('VIVO_VECTOR_MODEL') ?? 'bge-base-zh-v1.5',
    );
    const requestId = randomUUID();
    const startedAt = Date.now();
    const endpoint = this.config.get<string>('VIVO_EMBEDDING_ENDPOINT')
      ?? '/embedding-model-api/predict/batch';
    await this.assertDailyLimit(userId);
    try {
      const decoded = await this.vivo.postJson(endpoint, {
        model_name: runtime.model,
        sentences: [this.embeddingInputForModel(runtime.model, text)],
      }, { requestId });
      const vector = this.extractEmbeddingVector(decoded);
      if (!vector.length) throw new Error('empty embedding response');
      await this.logUsage(userId, 'embeddings', runtime, true, startedAt, text.length, vector.length);
      return {
        vector,
        capabilityTraces: [
          this.vivo.trace('Text embedding', endpoint, requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, 'embeddings', runtime, false, startedAt, text.length, 0, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  private async transcribeByLasr(
    userId: string,
    dto: SpeechTranscribeDto,
    requestId: string,
  ) {
    const audioBytes = this.audioBytesFromBase64(dto.audioBase64);
    if (!audioBytes.length) throw new Error('empty audio');
    const sessionId = randomUUID();
    const sliceSize = 5 * 1024 * 1024;
    const sliceNum = Math.max(1, Math.ceil(audioBytes.length / sliceSize));
    if (sliceNum > 100) throw new Error('audio file is too large for LASR');
    const query = this.lasrCommonQuery(userId, requestId);
    const audioType = (dto.mimeType ?? '').toLowerCase().includes('pcm')
      ? 'pcm'
      : 'auto';

    const created = await this.vivo.postJson('/lasr/create', {
      audio_type: audioType,
      'x-sessionId': sessionId,
      slice_num: sliceNum,
    }, query);
    const audioId = String((this.vivoData(created) as any)?.audio_id ?? '');
    if (!audioId) throw new Error('LASR audio_id missing');

    for (let index = 0; index < sliceNum; index += 1) {
      const start = index * sliceSize;
      const chunk = audioBytes.subarray(start, Math.min(start + sliceSize, audioBytes.length));
      const form = new FormData();
      form.append(
        'file',
        new Blob([chunk], { type: dto.mimeType ?? 'audio/m4a' }),
        `studytrace_${index}.${this.audioExtension(dto.mimeType)}`,
      );
      await this.vivo.postMultipart('/lasr/upload', form, {
        ...query,
        audio_id: audioId,
        slice_index: String(index),
        'x-sessionId': sessionId,
      });
    }

    const run = await this.vivo.postJson('/lasr/run', {
      audio_id: audioId,
      'x-sessionId': sessionId,
    }, query);
    const taskId = String((this.vivoData(run) as any)?.task_id ?? '');
    if (!taskId) throw new Error('LASR task_id missing');

    const pollCount = Number(this.config.get<string>('VIVO_LASR_POLL_COUNT') ?? 10);
    const pollIntervalMs = Number(this.config.get<string>('VIVO_LASR_POLL_INTERVAL_MS') ?? 1000);
    for (let attempt = 0; attempt < pollCount; attempt += 1) {
      const progressResponse = await this.vivo.postJson('/lasr/progress', {
        task_id: taskId,
        'x-sessionId': sessionId,
      }, query);
      const progress = Number((this.vivoData(progressResponse) as any)?.progress ?? 0);
      if (progress >= 100) break;
      await this.sleep(pollIntervalMs);
    }

    const result = await this.vivo.postJson('/lasr/result', {
      task_id: taskId,
      'x-sessionId': sessionId,
    }, query);
    return this.extractLasrText(result);
  }

  private lasrCommonQuery(userId: string, requestId: string) {
    return {
      client_version: this.config.get<string>('VIVO_LASR_CLIENT_VERSION') ?? '1.0.0',
      package: this.config.get<string>('VIVO_LASR_PACKAGE') ?? 'com.studytrace.app',
      user_id: this.lasrUserId(userId),
      system_time: Date.now().toString(),
      engineid: this.config.get<string>('VIVO_LASR_ENGINE_ID') ?? 'fileasrrecorder',
      requestId,
    };
  }

  private lasrUserId(userId: string) {
    return createHash('md5').update(userId).digest('hex');
  }

  private audioBytesFromBase64(value: string) {
    const raw = value.includes(',') ? value.split(',').pop() ?? '' : value;
    return Buffer.from(raw, 'base64');
  }

  private audioExtension(mimeType = 'audio/m4a') {
    if (mimeType.includes('wav')) return 'wav';
    if (mimeType.includes('mp3')) return 'mp3';
    if (mimeType.includes('aac')) return 'aac';
    if (mimeType.includes('ogg')) return 'ogg';
    if (mimeType.includes('pcm')) return 'pcm';
    return 'm4a';
  }

  private vivoData(decoded: unknown) {
    const data = decoded as any;
    const code = data?.code ?? data?.retcode ?? data?.status_code;
    if (code !== undefined && code !== null && String(code) !== '0') {
      throw new Error(data?.desc ?? data?.message ?? 'vivo request failed');
    }
    return data?.data ?? data?.result ?? data;
  }

  private extractLasrText(decoded: unknown) {
    const data = this.vivoData(decoded) as any;
    const result = data?.result ?? data?.text ?? data?.onebest;
    if (Array.isArray(result)) {
      return result
        .map((item) => String(item?.onebest ?? item?.text ?? item ?? '').trim())
        .filter(Boolean)
        .join('\n')
        .trim();
    }
    return String(result ?? '').trim();
  }

  private sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private async poiCall(userId: string, ability: string, payload: Record<string, unknown>) {
    const runtime = this.getBlueHeartAbilityRuntime('poi-search');
    const requestId = randomUUID();
    const startedAt = Date.now();
    const envKey =
      ability === 'reverse-geocode'
        ? 'VIVO_REVERSE_GEOCODE_ENDPOINT'
        : 'VIVO_POI_SEARCH_ENDPOINT';
    await this.assertDailyLimit(userId);
    try {
      const decoded = await this.vivo.optionalPostJson(envKey, {
        ...payload,
        token: this.config.get<string>('VIVO_POI_TOKEN') ?? '',
        request_id: requestId,
      });
      await this.logUsage(userId, ability, runtime, true, startedAt, JSON.stringify(payload).length, JSON.stringify(decoded).length);
      return {
        result: decoded,
        capabilityTraces: [
          this.vivo.trace('POI and geocoding', envKey, requestId, startedAt, true, {
            model: runtime.model,
          }),
        ],
      };
    } catch (error) {
      await this.logUsage(userId, ability, runtime, false, startedAt, JSON.stringify(payload).length, 0, error);
      throw new ServiceUnavailableException(this.errorMessage(error));
    }
  }

  private extractTextResult(decoded: unknown) {
    const data = decoded as any;
    const candidates = [
      data?.text,
      data?.translation,
      data?.result?.text,
      data?.data?.text,
      data?.data?.translation,
      Array.isArray(data?.result) ? data.result[0] : null,
    ];
    return candidates.map((value) => String(value ?? '').trim()).find((value) => value.length > 0) ?? '';
  }

  private extractStringList(value: unknown): string[] {
    if (Array.isArray(value)) {
      return value
        .map((item) => String(item ?? '').trim())
        .filter((item) => item.length > 0);
    }
    const text = String(value ?? '').trim();
    return text ? [text] : [];
  }

  private imageGenerationParameters() {
    const configuredSize = this.config.get<string>('VIVO_IMAGE_SIZE_DEFAULT')?.trim();
    return {
      size: configuredSize && configuredSize.length > 0 ? configuredSize : '2K',
    };
  }

  private extractImageUrls(value: unknown): string[] {
    const urls: string[] = [];
    const add = (item: unknown) => {
      if (item == null) return;
      if (Array.isArray(item)) {
        item.forEach(add);
        return;
      }
      if (typeof item === 'object') {
        const data = item as Record<string, unknown>;
        [
          'url',
          'uri',
          'urls',
          'image',
          'images',
          'imageUrl',
          'image_url',
          'imageURL',
          'imageUrls',
          'image_urls',
          'downloadUrl',
          'download_url',
          'fileUrl',
          'file_url',
          'outputUrl',
          'output_url',
          'result',
          'data',
          'content',
          'output',
          'outputs',
          'resources',
          'items',
        ].forEach((key) => add(data[key]));
        return;
      }
      const text = String(item).trim();
      if (!text) return;
      const matches = text.match(/(?:https?:\/\/|data:image\/|file:\/\/)[^\s"'<>\])}]+/gi);
      const candidates = matches?.length ? matches : [text];
      candidates
        .map((url) => url.trim())
        .filter((url) => /^(https?:\/\/|data:image\/|file:\/\/)/i.test(url))
        .forEach((url) => {
          if (!urls.includes(url)) urls.push(url);
        });
    };
    add(value);
    return urls;
  }

  private videoGenerationContent(dto: VideoTaskSubmitDto, prompt: string) {
    const content: Record<string, unknown>[] = [
      {
        type: 'text',
        text: this.videoPromptWithOptions(prompt, dto),
      },
    ];
    const imageUrl = dto.imageUrl
      ?? (dto.imageBase64
        ? dto.imageBase64.startsWith('data:')
          ? dto.imageBase64
          : `data:image/png;base64,${dto.imageBase64}`
        : '');
    if (imageUrl) {
      content.push({
        type: 'image_url',
        image_url: { url: imageUrl },
      });
    }
    return content;
  }

  private videoPromptWithOptions(prompt: string, dto: VideoTaskSubmitDto) {
    const parts = [prompt];
    const ratio = dto.ratio ?? this.config.get<string>('VIVO_VIDEO_RATIO_DEFAULT') ?? '16:9';
    const duration = dto.duration ?? this.config.get<string>('VIVO_VIDEO_DURATION_DEFAULT') ?? '5';
    if (ratio && !prompt.includes('--ratio')) parts.push(`--ratio ${ratio}`);
    if (duration && !prompt.includes('--dur')) parts.push(`--dur ${duration}`);
    return parts.join(' ');
  }

  private vivoTaskQuery(requestId: string) {
    return {
      request_id: requestId,
      system_time: Math.floor(Date.now() / 1000).toString(),
      module: 'aigc',
    };
  }

  private numberArray(value: unknown): number[] {
    if (!Array.isArray(value)) return [];
    return value.map((item) => Number(item)).filter((item) => Number.isFinite(item));
  }

  private embeddingInputForModel(model: string, text: string) {
    if (model === 'bge-base-zh-v1.5') {
      const instruction = '为这个句子生成表示以用于检索相关文章：';
      return text.startsWith(instruction) ? text : `${instruction}${text}`;
    }
    return text;
  }

  private extractEmbeddingVector(decoded: unknown) {
    const data = decoded as any;
    const candidates = [
      data?.embedding,
      data?.vector,
      data?.data?.embedding,
      data?.data?.vector,
      Array.isArray(data?.data) ? data.data[0] : null,
      Array.isArray(data?.result) ? data.result[0] : null,
      data?.result?.embedding,
      data?.result?.vector,
    ];
    for (const candidate of candidates) {
      if (Array.isArray(candidate) && candidate.every((item) => typeof item !== 'object')) {
        const vector = this.numberArray(candidate);
        if (vector.length) return vector;
      }
      const nested = this.numberArray(candidate?.embedding ?? candidate?.vector);
      if (nested.length) return nested;
    }
    return [];
  }

  private cosine(left: number[], right: number[]) {
    if (!left.length || left.length !== right.length) return 0;
    let dot = 0;
    let leftSize = 0;
    let rightSize = 0;
    for (let i = 0; i < left.length; i += 1) {
      dot += left[i] * right[i];
      leftSize += left[i] * left[i];
      rightSize += right[i] * right[i];
    }
    return leftSize && rightSize ? dot / (Math.sqrt(leftSize) * Math.sqrt(rightSize)) : 0;
  }

  private payloadFor(
    runtime: ModelRuntime,
    messages: Record<string, unknown>[],
    dto: Partial<ChatDto>,
    stream: boolean,
  ) {
    const maxTokens = Number(dto.options?.maxTokens ?? 1800);
    const reasoningEffort = this.reasoningEffortFor(dto);
    return {
      model: runtime.model,
      messages,
      temperature: Number(dto.options?.temperature ?? 0.7),
      max_completion_tokens: this.maxCompletionTokensFor(maxTokens, reasoningEffort),
      top_p: Number(dto.options?.topP ?? 0.7),
      frequency_penalty: Number(dto.options?.frequencyPenalty ?? 0),
      presence_penalty: Number(dto.options?.presencePenalty ?? 0),
      reasoning_effort: reasoningEffort,
      stream,
      ...this.thinkingPayloadFor(runtime.model, dto.thinkingEnabled === true),
    };
  }

  private reasoningEffortFor(dto: Partial<ChatDto>) {
    const raw = String(dto.options?.reasoningEffort ?? '').trim();
    if (['minimal', 'low', 'medium', 'high'].includes(raw)) return raw;
    return dto.thinkingEnabled ? 'high' : 'minimal';
  }

  private maxCompletionTokensFor(maxTokens: number, reasoningEffort: string) {
    const thinkingBudget = {
      minimal: 0,
      low: 1024,
      medium: 2048,
      high: 4096,
    }[reasoningEffort] ?? 0;
    return Math.min(65536, Math.max(0, maxTokens + thinkingBudget));
  }

  private thinkingPayloadFor(model: string, enabled: boolean) {
    if (model.toLowerCase() === 'qwen3.5-plus') {
      return { enable_thinking: enabled };
    }
    return { thinking: { type: enabled ? 'enabled' : 'disabled' } };
  }

  private getRuntime(): ModelRuntime {
    return {
      provider: 'blueheart',
      apiKey: this.required('BLUEHEART_API_KEY'),
      baseUrl: this.config.get('BLUEHEART_BASE_URL') ?? 'https://api-ai.vivo.com.cn/v1/chat/completions',
      model: this.config.get('BLUEHEART_MODEL') ?? 'Doubao-Seed-2.0-mini',
    };
  }

  private getBlueHeartAbilityRuntime(model: string): ModelRuntime {
    return {
      provider: 'blueheart',
      apiKey: this.required('BLUEHEART_API_KEY'),
      baseUrl: 'https://api-ai.vivo.com.cn',
      model,
    };
  }

  private async recognizeImageText(imageBase64: string, runtime: ModelRuntime) {
    const appId = this.required('BLUEHEART_APP_ID');
    const requestId = randomUUID();
    const body = new URLSearchParams({
      image: imageBase64,
      pos: '2',
      businessid: `aigc${appId}`,
      sessid: requestId,
    });
    const response = await fetch(
      `https://api-ai.vivo.com.cn/ocr/general_recognition?requestId=${requestId}`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${runtime.apiKey}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body,
      },
    );
    const raw = await response.text();
    if (!response.ok) throw new Error(raw);
    const decoded = JSON.parse(raw);
    if (decoded?.error_code && decoded.error_code !== 0) {
      throw new Error(decoded?.error_msg ?? 'OCR failed');
    }
    return this.collectWords(decoded?.result).join('\n').trim();
  }

  private collectWords(node: unknown): string[] {
    if (node == null) return [];
    if (typeof node === 'string') {
      const trimmed = node.trim();
      return trimmed ? [trimmed] : [];
    }
    if (Array.isArray(node)) {
      return node.flatMap((item) => this.collectWords(item));
    }
    if (typeof node === 'object') {
      const map = node as Record<string, unknown>;
      const words: string[] = [];
      if (typeof map.words === 'string' && map.words.trim()) {
        words.push(map.words.trim());
      }
      for (const value of Object.values(map)) {
        words.push(...this.collectWords(value));
      }
      return words.filter((word, index, all) => index === 0 || all[index - 1] !== word);
    }
    return [];
  }

  private clipText(value: string, maxLength: number) {
    const cleaned = String(value ?? '').trim();
    return cleaned.length > maxLength ? cleaned.slice(0, maxLength) : cleaned;
  }

  private rewritePrompt(intent: string) {
    switch (intent) {
      case 'continue':
        return '接着往下写这段内容，保持相同的语气与风格，再写 1-2 个短段落；如果适合，补充为 Notion 块笔记格式的小标题或列表。';
      case 'rewrite_formal':
        return '把下面这段改写得更学术、更正式，保留原意。';
      case 'rewrite_casual':
        return '把下面这段改写得更口语化、更轻松，保留原意。';
      case 'rewrite_concise':
        return '把下面这段改写得更简洁，能删则删，保留核心观点。';
      case 'expand':
        return '把下面这段展开成更详细的 Notion 块笔记，增加例子或论证，用小标题、短段落和列表分块。';
      case 'outline':
        return '把下面这段总结成可扫读的块笔记：先给一个小标题，再列出 3-5 条 Markdown 要点。';
      default:
        return '请润色下面这段内容，保持原意。';
    }
  }

  private required(key: string) {
    const value = this.config.get<string>(key);
    if (!value) throw new ServiceUnavailableException(`${key} 未配置`);
    return value;
  }

  private urlFor(runtime: ModelRuntime) {
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

  private normalizeAssistantTurn(raw: string, input: string) {
    let decoded: Record<string, unknown> = {};
    let decodedOk = true;
    try {
      decoded = this.decodeJsonObject(raw) as Record<string, unknown>;
    } catch (_) {
      decodedOk = false;
      decoded = {};
    }

    const parsedActions = Array.isArray(decoded.actions)
      ? decoded.actions.filter(
          (item): item is Record<string, unknown> =>
            typeof item === 'object' && item !== null,
        )
      : [];
    const reply =
      typeof decoded.reply === 'string'
        ? decoded.reply.trim()
        : decodedOk
          ? ''
          : raw.trim();
    const normalizedActions = parsedActions.map((action) =>
      this.completeAssistantAction(action, input, reply),
    );
    const inferredAction = normalizedActions.length ? null : this.inferAssistantAction(input, reply);

    return {
      schemaVersion: Number(decoded.schemaVersion ?? decoded.schema_version ?? 2) || 2,
      reply:
        inferredAction && (!reply || this.isGenericAssistantFallback(reply))
          ? this.replyForAssistantAction(inferredAction.type)
          : reply || '我来帮你处理。',
      actions: inferredAction ? [inferredAction] : normalizedActions,
    };
  }

  private completeAssistantAction(
    action: Record<string, unknown>,
    input: string,
    reply: string,
  ) {
    const type = String(action.type ?? action.toolId ?? action.action ?? '').trim();
    if (
      this.isNoteSaveAction(type) &&
      !this.stringifyChatContent(action.content) &&
      this.isUsefulGeneratedNote(reply, input)
    ) {
      return {
        ...action,
        title: action.title ?? this.noteTitleFromInput(input),
        content: reply,
      };
    }
    return action;
  }

  private inferAssistantAction(input: string, reply = '') {
    const normalized = input.trim();
    if (this.isImageGenerationIntent(normalized)) {
      return {
        actionId: 'act_1',
        type: 'media.generate_image',
        title: '生成图片',
        sourceText: normalized,
      };
    }
    if (this.isNoteGenerationIntent(normalized) && this.isUsefulGeneratedNote(reply, normalized)) {
      return {
        actionId: 'act_1',
        type: 'note.save',
        title: this.noteTitleFromInput(normalized),
        content: reply,
      };
    }
    return null;
  }

  private isNoteSaveAction(type: string) {
    const normalized = type.toLowerCase().replace(/[-_]/g, '.');
    return normalized === 'note.save' || normalized === 'save.note';
  }

  private isNoteGenerationIntent(input: string) {
    return (
      /(生成|制作|制作为|整理成|整理|写成|写|创建|保存|做成|做|产出|转成).{0,16}(笔记|学习笔记|课堂笔记|复习笔记)/.test(input) ||
      /(笔记|学习笔记|课堂笔记|复习笔记).{0,16}(生成|制作|保存|创建|整理|写成|写|做成|做|产出|转成)/.test(input)
    );
  }

  private isUsefulGeneratedNote(content: string, input: string) {
    const text = content.trim();
    if (text.length < 40) return false;
    if (text === input.trim()) return false;
    if (this.isGenericAssistantFallback(text)) return false;
    return /[#\n。；;：:\-•*]/.test(text);
  }

  private noteTitleFromInput(input: string) {
    const topic = input
      .replace(/帮我|请|生成|制作|制作为|整理成|整理|写成|写|创建|保存|做成|做|产出|转成/g, '')
      .replace(/一个|一份|一篇|详细的|详细|完整的|完整|学习笔记|课堂笔记|复习笔记|笔记/g, '')
      .replace(/[，。！？!?：:\s]+/g, '')
      .trim();
    return `${topic || '学习'}笔记`;
  }

  private isImageGenerationIntent(input: string) {
    return (
      /(生成|画|绘制|做|制作|设计).{0,10}(图片|图像|配图|插图|图解|流程图|示意图|知识图谱)/.test(
        input,
      ) ||
      /(图片|图像|配图|插图|图解|流程图|示意图|知识图谱).{0,10}(生成|画|绘制|做|制作|设计)/.test(
        input,
      ) ||
      /(画图|做图|文生图|生成一张|以图呈现)/.test(input)
    );
  }

  private isGenericAssistantFallback(reply: string) {
    return /(无法识别|提供清晰的指令|具体需求|帮您操作StudyTrace App)/.test(reply);
  }

  private replyForAssistantAction(type: string) {
    if (type === 'media.generate_image') {
      return '好，我来先帮你生成这张图片。';
    }
    return '我来帮你处理。';
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
