import { Body, Controller, Post, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { CurrentUser, CurrentUserPayload } from '../../common/current-user.decorator';
import { JwtAuthGuard } from '../../common/jwt-auth.guard';
import { AiService } from './ai.service';
import { ChatDto, FlashCardsDto, RiskWarningsDto, TextInputDto, WeeklyAnalysisDto } from './dto/ai-common.dto';

@UseGuards(JwtAuthGuard)
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
}
