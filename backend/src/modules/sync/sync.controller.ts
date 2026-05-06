import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { CurrentUser, CurrentUserPayload } from '../../common/current-user.decorator';
import { JwtAuthGuard } from '../../common/jwt-auth.guard';
import { PushSyncDto } from './dto/push-sync.dto';
import { SyncService } from './sync.service';

@UseGuards(JwtAuthGuard)
@Controller('sync')
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  @Post('push')
  push(@CurrentUser() user: CurrentUserPayload, @Body() dto: PushSyncDto) {
    return this.sync.push(user.userId, dto);
  }

  @Get('pull')
  pull(@CurrentUser() user: CurrentUserPayload, @Query('cursor') cursor?: string) {
    return this.sync.pull(user.userId, cursor);
  }

  @Get('export')
  exportAll(@CurrentUser() user: CurrentUserPayload) {
    return this.sync.exportAll(user.userId);
  }
}
