import { Body, Controller, Get, Post, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { CurrentUser, CurrentUserPayload } from '../../common/current-user.decorator';
import { JwtAuthGuard } from '../../common/jwt-auth.guard';
import { RateLimitGuard } from '../../common/rate-limit.guard';
import { AiService } from './ai.service';
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

@UseGuards(JwtAuthGuard, RateLimitGuard)
@Controller('ai')
export class AiController {
  constructor(private readonly ai: AiService) {}

  @Post('study-log')
  studyLog(@CurrentUser() user: CurrentUserPayload, @Body() dto: TextInputDto) {
    return this.ai.generateStudyLog(user.userId, dto);
  }

  @Post('task-plan')
  taskPlan(@CurrentUser() user: CurrentUserPayload, @Body() dto: TextInputDto) {
    return this.ai.generateTaskPlan(user.userId, dto);
  }

  @Post('weekly-analysis')
  weeklyAnalysis(@CurrentUser() user: CurrentUserPayload, @Body() dto: WeeklyAnalysisDto) {
    return this.ai.generateWeeklyAnalysis(user.userId, dto);
  }

  @Post('risk-warnings')
  riskWarnings(@CurrentUser() user: CurrentUserPayload, @Body() dto: RiskWarningsDto) {
    return this.ai.generateRiskWarnings(user.userId, dto);
  }

  @Post('flash-cards')
  flashCards(@CurrentUser() user: CurrentUserPayload, @Body() dto: FlashCardsDto) {
    return this.ai.generateFlashCards(user.userId, dto);
  }

  @Post('weekly-plan')
  weeklyPlan(@CurrentUser() user: CurrentUserPayload, @Body() dto: WeeklyPlanDto) {
    return this.ai.generateWeeklyPlan(user.userId, dto);
  }

  @Post('learning-loop')
  learningLoop(@CurrentUser() user: CurrentUserPayload, @Body() dto: LearningLoopDto) {
    return this.ai.generateLearningLoop(user.userId, dto);
  }

  @Post('rewrite')
  rewrite(@CurrentUser() user: CurrentUserPayload, @Body() dto: RewriteDto) {
    return this.ai.rewrite(user.userId, dto);
  }

  @Post('grade-flashcard')
  gradeFlashcard(@CurrentUser() user: CurrentUserPayload, @Body() dto: FlashCardGradeDto) {
    return this.ai.gradeFlashcard(user.userId, dto);
  }

  @Post('ocr')
  ocr(@CurrentUser() user: CurrentUserPayload, @Body() dto: OcrDto) {
    return this.ai.ocr(user.userId, dto);
  }

  @Post('query-rewrite')
  queryRewrite(@CurrentUser() user: CurrentUserPayload, @Body() dto: QueryRewriteDto) {
    return this.ai.queryRewrite(user.userId, dto);
  }

  @Post('rerank')
  rerank(@CurrentUser() user: CurrentUserPayload, @Body() dto: RerankDto) {
    return this.ai.rerank(user.userId, dto);
  }

  @Post('translate')
  translate(@CurrentUser() user: CurrentUserPayload, @Body() dto: TranslateDto) {
    return this.ai.translate(user.userId, dto);
  }

  @Post('images/tasks')
  submitImageTask(@CurrentUser() user: CurrentUserPayload, @Body() dto: ImageTaskSubmitDto) {
    return this.ai.submitImageTask(user.userId, dto);
  }

  @Post('images/tasks/status')
  queryImageTask(@CurrentUser() user: CurrentUserPayload, @Body() dto: ImageTaskQueryDto) {
    return this.ai.queryImageTask(user.userId, dto);
  }

  @Post('videos/tasks')
  submitVideoTask(@CurrentUser() user: CurrentUserPayload, @Body() dto: VideoTaskSubmitDto) {
    return this.ai.submitVideoTask(user.userId, dto);
  }

  @Post('videos/tasks/status')
  queryVideoTask(@CurrentUser() user: CurrentUserPayload, @Body() dto: VideoTaskQueryDto) {
    return this.ai.queryVideoTask(user.userId, dto);
  }

  @Post('speech/transcribe')
  transcribeSpeech(@CurrentUser() user: CurrentUserPayload, @Body() dto: SpeechTranscribeDto) {
    return this.ai.transcribeSpeech(user.userId, dto);
  }

  @Post('embeddings')
  embeddings(@CurrentUser() user: CurrentUserPayload, @Body() dto: EmbeddingIndexDto) {
    return this.ai.indexMemory(user.userId, dto);
  }

  @Post('memory/index')
  memoryIndex(@CurrentUser() user: CurrentUserPayload, @Body() dto: EmbeddingIndexDto) {
    return this.ai.indexMemory(user.userId, dto);
  }

  @Post('memory/search')
  memorySearch(@CurrentUser() user: CurrentUserPayload, @Body() dto: EmbeddingSearchDto) {
    return this.ai.searchMemory(user.userId, dto);
  }

  @Post('poi-search')
  poiSearch(@CurrentUser() user: CurrentUserPayload, @Body() dto: PoiSearchDto) {
    return this.ai.poiSearch(user.userId, dto);
  }

  @Post('reverse-geocode')
  reverseGeocode(@CurrentUser() user: CurrentUserPayload, @Body() dto: ReverseGeocodeDto) {
    return this.ai.reverseGeocode(user.userId, dto);
  }

  @Get('capability-badges')
  capabilityBadges(@CurrentUser() user: CurrentUserPayload) {
    return this.ai.capabilityBadges(user.userId);
  }

  @Post('chat')
  chat(@CurrentUser() user: CurrentUserPayload, @Body() dto: ChatDto) {
    return this.ai.chat(user.userId, dto);
  }

  @Post('chat/stream')
  async chatStream(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: ChatDto,
    @Res() response: Response,
  ) {
    response.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    response.setHeader('Cache-Control', 'no-cache, no-transform');
    response.setHeader('Connection', 'keep-alive');

    try {
      await this.ai.streamChat(user.userId, dto, (chunk) => {
        response.write(`data: ${JSON.stringify({ delta: chunk })}\n\n`);
      });
      response.write('data: [DONE]\n\n');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      response.write(`event: error\ndata: ${JSON.stringify({ message })}\n\n`);
    } finally {
      response.end();
    }
  }

  @Get('usage/today')
  usageToday(@CurrentUser() user: CurrentUserPayload) {
    return this.ai.todayUsage(user.userId);
  }
}
