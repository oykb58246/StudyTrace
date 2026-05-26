import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { GroupRole } from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateGroupDto } from './dto/create-group.dto';
import { JoinGroupDto } from './dto/join-group.dto';

@Injectable()
export class GroupsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateGroupDto) {
    const inviteCode = await this.generateInviteCode();
    const group = await this.prisma.$transaction(async (tx) => {
      const created = await tx.group.create({
        data: {
          name: dto.name.trim(),
          description: dto.description?.trim() || null,
          inviteCode,
          members: {
            create: {
              userId,
              role: GroupRole.OWNER,
            },
          },
          invites: {
            create: {
              code: inviteCode,
              createdById: userId,
            },
          },
        },
      });
      return created;
    });

    return this.getGroupForMember(userId, group.id);
  }

  async join(userId: string, dto: JoinGroupDto) {
    const code = dto.inviteCode.trim().toUpperCase();
    const invite = await this.prisma.groupInvite.findUnique({
      where: { code },
      include: { group: true },
    });
    if (!invite || invite.disabledAt) throw new NotFoundException('邀请码无效');
    if (invite.expiresAt && invite.expiresAt.getTime() < Date.now()) {
      throw new NotFoundException('邀请码已过期');
    }

    await this.prisma.groupMember.upsert({
      where: {
        groupId_userId: {
          groupId: invite.groupId,
          userId,
        },
      },
      create: {
        groupId: invite.groupId,
        userId,
        role: GroupRole.MEMBER,
      },
      update: {
        leftAt: null,
        joinedAt: new Date(),
      },
    });

    return this.getGroupForMember(userId, invite.groupId);
  }

  async getGroupForMember(userId: string, groupId: string) {
    await this.ensureMember(userId, groupId);
    const group = await this.prisma.group.findUnique({
      where: { id: groupId },
      include: {
        members: {
          where: { leftAt: null },
        },
      },
    });
    if (!group) throw new NotFoundException('小组不存在');
    return {
      id: group.id,
      name: group.name,
      description: group.description,
      inviteCode: group.inviteCode,
      memberCount: group.members.length,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    };
  }

  async listMyGroups(userId: string) {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId, leftAt: null },
      include: {
        group: {
          include: {
            members: {
              where: { leftAt: null },
            },
          },
        },
      },
      orderBy: { joinedAt: 'desc' },
    });
    return memberships.map((membership) => ({
      id: membership.group.id,
      name: membership.group.name,
      description: membership.group.description,
      inviteCode: membership.group.inviteCode,
      memberCount: membership.group.members.length,
      role: membership.role.toLowerCase(),
      joinedAt: membership.joinedAt,
    }));
  }

  async listMembers(userId: string, groupId: string) {
    await this.ensureMember(userId, groupId);
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, leftAt: null },
      include: {
        user: {
          include: { profile: true },
        },
      },
      orderBy: { joinedAt: 'asc' },
    });
    return members.map((member) => ({
      id: member.user.id,
      username: member.user.username,
      role: member.role.toLowerCase(),
      joinedAt: member.joinedAt,
      profile: member.user.profile,
    }));
  }

  async listActivities(userId: string, groupId: string) {
    await this.ensureMember(userId, groupId);
    const activities = await this.prisma.studyActivity.findMany({
      where: { groupId },
      include: {
        user: {
          include: { profile: true },
        },
      },
      orderBy: { happenedAt: 'desc' },
      take: 50,
    });
    return activities.map((activity) => ({
      id: activity.id,
      type: activity.type,
      title: activity.title,
      summary: activity.summary,
      sourceType: activity.sourceType,
      sourceId: activity.sourceId,
      payloadJson: activity.payloadJson,
      happenedAt: activity.happenedAt,
      createdAt: activity.createdAt,
      user: {
        id: activity.user.id,
        username: activity.user.username,
        profile: activity.user.profile,
      },
    }));
  }

  async leave(userId: string, groupId: string) {
    const membership = await this.ensureMember(userId, groupId);
    if (membership.role === GroupRole.OWNER) {
      throw new ForbiddenException('创建者暂不支持退出小组');
    }
    await this.prisma.groupMember.update({
      where: { id: membership.id },
      data: { leftAt: new Date() },
    });
    return { ok: true };
  }

  async ensureMember(userId: string, groupId: string) {
    const membership = await this.prisma.groupMember.findUnique({
      where: {
        groupId_userId: {
          groupId,
          userId,
        },
      },
    });
    if (!membership || membership.leftAt) {
      throw new ForbiddenException('没有访问该小组的权限');
    }
    return membership;
  }

  private async generateInviteCode() {
    for (let i = 0; i < 5; i += 1) {
      const code = `ST${randomBytes(4).toString('hex').toUpperCase()}`;
      const existing = await this.prisma.groupInvite.findUnique({ where: { code } });
      if (!existing) return code;
    }
    throw new Error('生成邀请码失败');
  }
}
