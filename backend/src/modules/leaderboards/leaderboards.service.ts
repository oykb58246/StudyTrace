import { Injectable } from '@nestjs/common';
import { startOfRange, startOfToday } from '../../common/date-range';
import { GroupsService } from '../groups/groups.service';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class LeaderboardsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
  ) {}

  async getMine(userId: string) {
    const [totalPoints, todayPoints, weekPoints, monthPoints] = await Promise.all([
      this.sumUserPoints(userId),
      this.sumUserPoints(userId, startOfToday()),
      this.sumUserPoints(userId, startOfRange('week')),
      this.sumUserPoints(userId, startOfRange('month')),
    ]);

    return {
      totalPoints,
      todayPoints,
      weekPoints,
      monthPoints,
    };
  }

  async getGroupLeaderboard(
    userId: string,
    groupId: string,
    range: 'week' | 'month' = 'week',
    metric = 'points',
  ) {
    await this.groups.ensureMember(userId, groupId);
    if (metric && metric !== 'points') {
      return this.getEvidenceMetricLeaderboard(userId, groupId, range, metric);
    }
    const since = startOfRange(range);
    const rows = await this.prisma.scoreEvent.groupBy({
      by: ['userId'],
      where: {
        groupId,
        happenedAt: { gte: since },
      },
      _sum: { points: true },
    });

    const userIds = rows.map((row) => row.userId);
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      include: { profile: true },
    });
    const userById = new Map(users.map((user) => [user.id, user]));

    return rows
      .map((row) => ({
        userId: row.userId,
        points: row._sum.points ?? 0,
        user: userById.get(row.userId),
      }))
      .sort((a, b) => b.points - a.points || (a.user?.username ?? '').localeCompare(b.user?.username ?? ''))
      .map((row, index) => ({
        rank: index + 1,
        userId: row.userId,
        points: row.points,
        username: row.user?.username,
        profile: row.user?.profile,
      }));
  }

  private async getEvidenceMetricLeaderboard(
    userId: string,
    groupId: string,
    range: 'week' | 'month',
    metric: string,
  ) {
    await this.groups.ensureMember(userId, groupId);
    const since = startOfRange(range);
    const db = this.prisma as any;
    const rows = await this.metricRows(db, groupId, since, metric);
    const userIds = rows.map((row: { userId: string }) => row.userId);
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      include: { profile: true },
    });
    const userById = new Map(users.map((user) => [user.id, user]));
    return rows
      .map((row: { userId: string; points: number }) => ({
        ...row,
        user: userById.get(row.userId),
      }))
      .sort((a, b) => b.points - a.points || (a.user?.username ?? '').localeCompare(b.user?.username ?? ''))
      .map((row, index) => ({
        rank: index + 1,
        userId: row.userId,
        points: row.points,
        username: row.user?.username,
        profile: row.user?.profile,
        metric,
      }));
  }

  private async metricRows(db: any, groupId: string, since: Date, metric: string) {
    if (metric === 'evidencePackages') {
      const rows = await db.evidencePackage.groupBy({
        by: ['userId'],
        where: {
          groupId,
          visibility: { in: ['group', 'public'] },
          createdAt: { gte: since },
        },
        _count: { _all: true },
      });
      return rows.map((row) => ({ userId: row.userId, points: row._count._all }));
    }
    if (metric === 'challengeEvidence') {
      const challenges = await db.groupChallenge.findMany({
        where: { groupId },
        select: { id: true },
      });
      const challengeIds = challenges.map((item) => item.id);
      if (!challengeIds.length) return [];
      const rows = await db.challengeEvidence.groupBy({
        by: ['userId'],
        where: {
          challengeId: { in: challengeIds },
          happenedAt: { gte: since },
        },
        _count: { _all: true },
      });
      return rows.map((row) => ({ userId: row.userId, points: row._count._all }));
    }
    const activityTypes =
      metric === 'loops'
        ? ['aiLoopApplied']
        : metric === 'review'
          ? ['studyLogCreated', 'noteCreated', 'flashcardBatchCreated', 'voiceReview']
          : metric === 'streak'
            ? ['dailyStreak']
            : [];
    if (!activityTypes.length) return [];
    const rows = await this.prisma.studyActivity.groupBy({
      by: ['userId'],
      where: {
        groupId,
        type: { in: activityTypes },
        happenedAt: { gte: since },
      },
      _count: { _all: true },
    });
    return rows.map((row) => ({ userId: row.userId, points: row._count._all }));
  }

  private async sumUserPoints(userId: string, since?: Date) {
    const result = await this.prisma.scoreEvent.aggregate({
      where: {
        userId,
        groupId: null,
        ...(since ? { happenedAt: { gte: since } } : {}),
      },
      _sum: { points: true },
    });
    return result._sum.points ?? 0;
  }
}
