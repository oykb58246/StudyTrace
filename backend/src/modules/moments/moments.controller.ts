import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser, CurrentUserPayload } from '../../common/current-user.decorator';
import { JwtAuthGuard } from '../../common/jwt-auth.guard';
import { CreateMomentCommentDto, CreateMomentDto, MomentVisibilityDto } from './dto/moments.dto';
import { MomentsService } from './moments.service';

@UseGuards(JwtAuthGuard)
@Controller('moments')
export class MomentsController {
  constructor(private readonly moments: MomentsService) {}

  @Post()
  create(@CurrentUser() user: CurrentUserPayload, @Body() dto: CreateMomentDto) {
    return this.moments.create(user.userId, dto);
  }

  @Get('feed')
  feed(@CurrentUser() user: CurrentUserPayload) {
    return this.moments.feed(user.userId);
  }

  @Patch(':id/visibility')
  updateVisibility(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') momentId: string,
    @Body() dto: MomentVisibilityDto,
  ) {
    return this.moments.updateVisibility(user.userId, momentId, dto);
  }

  @Delete(':id')
  delete(@CurrentUser() user: CurrentUserPayload, @Param('id') momentId: string) {
    return this.moments.delete(user.userId, momentId);
  }

  @Post(':id/likes/me')
  like(@CurrentUser() user: CurrentUserPayload, @Param('id') momentId: string) {
    return this.moments.like(user.userId, momentId);
  }

  @Delete(':id/likes/me')
  unlike(@CurrentUser() user: CurrentUserPayload, @Param('id') momentId: string) {
    return this.moments.unlike(user.userId, momentId);
  }

  @Post(':id/comments')
  comment(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') momentId: string,
    @Body() dto: CreateMomentCommentDto,
  ) {
    return this.moments.comment(user.userId, momentId, dto);
  }

  @Delete(':id/comments/:commentId')
  deleteComment(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') momentId: string,
    @Param('commentId') commentId: string,
  ) {
    return this.moments.deleteComment(user.userId, momentId, commentId);
  }
}
