import { Injectable } from '@nestjs/common';
import { Prisma, ScoreEvent } from '@prisma/client';
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
    const groupIds = dto.groupId ? [dto.groupId] : [];
    for (const groupId of groupIds) {
      await this.groups.ensureMember(userId, groupId);
    }

    const happenedAt = dto.happenedAt ? new Date(dto.happenedAt) : new Date();
    const payloadJson = (dto.payloadJson ?? {}) as Prisma.InputJsonValue;
    const data: Prisma.StudyActivityCreateManyInput = {
      userId,
      type: dto.type,
      title: dto.title.trim(),
      summary: dto.summary?.trim() || null,
      sourceType: dto.sourceType ?? null,
      sourceId: dto.sourceId ?? null,
      payloadJson,
      happenedAt,
    };

    const primaryActivity = await this.prisma.studyActivity.create({
      data: { ...data, groupId: groupIds[0] ?? null },
    });
    if (groupIds.length > 1) {
      await this.prisma.studyActivity.createMany({
        data: groupIds.slice(1).map((groupId) => ({ ...data, groupId })),
      });
    }

    const scoreEvents = await this.createScoreEvents(
      userId,
      dto,
      happenedAt,
      groupIds,
    );
    return { activity: primaryActivity, scoreEvents };
  }

  async listMine(userId: string) {
    const activities = await this.prisma.studyActivity.findMany({
      where: { userId },
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
      groupId: activity.groupId,
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

  private async createScoreEvents(
    userId: string,
    dto: CreateActivityDto,
    happenedAt: Date,
    groupIds: string[],
  ) {
    const score = scoreForActivity(dto.type, dto.payloadJson);
    if (score.points <= 0) return [];

    const targets: Array<string | null> = [null, ...groupIds];
    const created: ScoreEvent[] = [];
    for (const groupId of targets) {
      if (dto.sourceType && dto.sourceId) {
        const existing = await this.prisma.scoreEvent.findFirst({
          where: {
            userId,
            groupId,
            sourceType: dto.sourceType,
            sourceId: dto.sourceId,
            reason: score.reason,
          },
        });
        if (existing) {
          created.push(existing);
          continue;
        }
      }
      created.push(await this.prisma.scoreEvent.create({
        data: {
          userId,
          groupId,
          points: score.points,
          reason: score.reason,
          sourceType: dto.sourceType ?? null,
          sourceId: dto.sourceId ?? null,
          happenedAt,
        },
      }));
    }

    return created;
  }
}
