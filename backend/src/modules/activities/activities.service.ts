import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { GroupsService } from '../groups/groups.service';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateActivityDto } from './dto/create-activity.dto';
import { scoreForActivity } from './score-rules';

@Injectable()
export class ActivitiesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
  ) {}

  async create(userId: string, dto: CreateActivityDto) {
    if (dto.groupId) {
      await this.groups.ensureMember(userId, dto.groupId);
    }

    const happenedAt = dto.happenedAt ? new Date(dto.happenedAt) : new Date();
    const payloadJson = (dto.payloadJson ?? {}) as Prisma.InputJsonValue;
    const activity = await this.prisma.studyActivity.create({
      data: {
        userId,
        groupId: dto.groupId ?? null,
        type: dto.type,
        title: dto.title.trim(),
        summary: dto.summary?.trim() || null,
        sourceType: dto.sourceType ?? null,
        sourceId: dto.sourceId ?? null,
        payloadJson,
        happenedAt,
      },
    });

    const scoreEvent = await this.createScoreEvent(userId, dto, happenedAt);
    return { activity, scoreEvent };
  }

  async listMine(userId: string) {
    return this.prisma.studyActivity.findMany({
      where: { userId },
      orderBy: { happenedAt: 'desc' },
      take: 50,
    });
  }

  private async createScoreEvent(userId: string, dto: CreateActivityDto, happenedAt: Date) {
    const score = scoreForActivity(dto.type, dto.payloadJson);
    if (score.points <= 0) return null;

    if (dto.sourceType && dto.sourceId) {
      const existing = await this.prisma.scoreEvent.findFirst({
        where: {
          userId,
          sourceType: dto.sourceType,
          sourceId: dto.sourceId,
          reason: score.reason,
        },
      });
      if (existing) return existing;
    }

    return this.prisma.scoreEvent.create({
      data: {
        userId,
        groupId: dto.groupId ?? null,
        points: score.points,
        reason: score.reason,
        sourceType: dto.sourceType ?? null,
        sourceId: dto.sourceId ?? null,
        happenedAt,
      },
    });
  }
}
