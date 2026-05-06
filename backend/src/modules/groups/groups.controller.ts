import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser, CurrentUserPayload } from '../../common/current-user.decorator';
import { JwtAuthGuard } from '../../common/jwt-auth.guard';
import { CreateGroupDto } from './dto/create-group.dto';
import { JoinGroupDto } from './dto/join-group.dto';
import { GroupsService } from './groups.service';

@UseGuards(JwtAuthGuard)
@Controller('groups')
export class GroupsController {
  constructor(private readonly groups: GroupsService) {}

  @Post()
  create(@CurrentUser() user: CurrentUserPayload, @Body() dto: CreateGroupDto) {
    return this.groups.create(user.userId, dto);
  }

  @Post('join')
  join(@CurrentUser() user: CurrentUserPayload, @Body() dto: JoinGroupDto) {
    return this.groups.join(user.userId, dto);
  }

  @Get()
  listMine(@CurrentUser() user: CurrentUserPayload) {
    return this.groups.listMyGroups(user.userId);
  }

  @Get(':id')
  get(@CurrentUser() user: CurrentUserPayload, @Param('id') groupId: string) {
    return this.groups.getGroupForMember(user.userId, groupId);
  }

  @Get(':id/members')
  members(@CurrentUser() user: CurrentUserPayload, @Param('id') groupId: string) {
    return this.groups.listMembers(user.userId, groupId);
  }

  @Get(':id/activities')
  activities(@CurrentUser() user: CurrentUserPayload, @Param('id') groupId: string) {
    return this.groups.listActivities(user.userId, groupId);
  }

  @Delete(':id/membership')
  leave(@CurrentUser() user: CurrentUserPayload, @Param('id') groupId: string) {
    return this.groups.leave(user.userId, groupId);
  }
}
