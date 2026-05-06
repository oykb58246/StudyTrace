import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { CurrentUser, CurrentUserPayload } from '../../common/current-user.decorator';
import { JwtAuthGuard } from '../../common/jwt-auth.guard';
import { LeaderboardsService } from './leaderboards.service';

@UseGuards(JwtAuthGuard)
@Controller('leaderboards')
export class LeaderboardsController {
  constructor(private readonly leaderboards: LeaderboardsService) {}

  @Get('me')
  getMine(@CurrentUser() user: CurrentUserPayload) {
    return this.leaderboards.getMine(user.userId);
  }

  @Get('groups/:id')
  getGroup(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') groupId: string,
    @Query('range') range?: 'week' | 'month',
  ) {
    const safeRange = range === 'month' ? 'month' : 'week';
    return this.leaderboards.getGroupLeaderboard(user.userId, groupId, safeRange);
  }
}
