import { Injectable, NotFoundException } from '@nestjs/common';
import { ActivitiesService } from '../activities/activities.service';
import { AiService } from '../ai/ai.service';
import { GroupsService } from '../groups/groups.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  AddChallengeEvidenceDto,
  ChallengeDraftDto,
  CreateChallengeDto,
  CreateEvidencePackageDto,
  CreateLocationCheckInDto,
  UpdateEvidencePackageDto,
} from './dto/community-evidence.dto';

@Injectable()
export class CommunityEvidenceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
    private readonly activities: ActivitiesService,
    private readonly ai: AiService,
  ) {}

  async draftChallenge(userId: string, groupId: string, dto: ChallengeDraftDto) {
    const group = await this.groups.getGroupForMember(userId, groupId);
    const input = [
      `Create a 3-7 day StudyTrace group challenge for group "${group.name}".`,
      'It must focus on learning evidence chain, not a generic question bank.',
      'Return concise Chinese text with title, daily actions, scoring, and final evidence-package showcase.',
      ...(dto.context ?? []),
    ].join('\n');
    const result = (await this.ai.chat(userId, { input, purpose: 'chat' })) as any;
    return {
      draftText: result.content,
      groupId,
      capabilityTraces: result.capabilityTraces ?? [],
    };
  }

  async createChallenge(userId: string, groupId: string, dto: CreateChallengeDto) {
    await this.groups.ensureMember(userId, groupId);
    const db = this.prisma as any;
    const challenge = await db.groupChallenge.create({
      data: {
        groupId,
        createdById: userId,
        title: dto.title.trim(),
        description: dto.description?.trim() || null,
        planJson: dto.planJson,
        scoringJson: dto.scoringJson ?? null,
        coverImageUrl: dto.coverImageUrl ?? null,
        startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
        endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
      },
    });
    await db.challengeParticipation.create({
      data: { challengeId: challenge.id, userId },
    });
    return this.withCounts(challenge);
  }

  async listChallenges(userId: string, groupId: string) {
    await this.groups.ensureMember(userId, groupId);
    const db = this.prisma as any;
    const rows = await db.groupChallenge.findMany({
      where: { groupId },
      include: {
        participations: true,
        evidences: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return rows.map((row) => this.withCounts(row));
  }

  async joinChallenge(userId: string, groupId: string, challengeId: string) {
    await this.ensureChallengeMember(userId, groupId, challengeId);
    const db = this.prisma as any;
    return db.challengeParticipation.upsert({
      where: { challengeId_userId: { challengeId, userId } },
      create: { challengeId, userId },
      update: {},
    });
  }

  async addChallengeEvidence(
    userId: string,
    groupId: string,
    challengeId: string,
    dto: AddChallengeEvidenceDto,
  ) {
    await this.ensureChallengeMember(userId, groupId, challengeId);
    const db = this.prisma as any;
    const evidence = await db.challengeEvidence.create({
      data: {
        challengeId,
        userId,
        evidenceType: dto.evidenceType.trim(),
        title: dto.title.trim(),
        summary: dto.summary?.trim() || null,
        sourceType: dto.sourceType ?? null,
        sourceId: dto.sourceId ?? null,
        payloadJson: dto.payloadJson ?? null,
        happenedAt: dto.happenedAt ? new Date(dto.happenedAt) : new Date(),
      },
    });
    const evidenceCount = await db.challengeEvidence.count({
      where: { challengeId, userId },
    });
    await db.challengeParticipation.upsert({
      where: { challengeId_userId: { challengeId, userId } },
      create: { challengeId, userId, evidenceCount, progress: Math.min(100, evidenceCount * 20) },
      update: { evidenceCount, progress: Math.min(100, evidenceCount * 20) },
    });
    await this.activities.create(userId, {
      type: 'challengeEvidence',
      title: dto.title,
      summary: dto.summary,
      groupId,
      sourceType: dto.sourceType ?? 'challenge_evidence',
      sourceId: dto.sourceId ?? evidence.id,
      payloadJson: {
        challengeId,
        evidenceType: dto.evidenceType,
      },
      happenedAt: evidence.happenedAt.toISOString(),
    });
    return evidence;
  }

  async challengeLeaderboard(userId: string, groupId: string, challengeId: string) {
    await this.ensureChallengeMember(userId, groupId, challengeId);
    const db = this.prisma as any;
    const rows = await db.challengeParticipation.findMany({
      where: { challengeId },
      include: { user: { include: { profile: true } } },
      orderBy: [{ evidenceCount: 'desc' }, { progress: 'desc' }, { joinedAt: 'asc' }],
    });
    return rows.map((row, index) => ({
      rank: index + 1,
      userId: row.userId,
      username: row.user?.username,
      profile: row.user?.profile,
      points: row.evidenceCount,
      progress: row.progress,
      evidenceCount: row.evidenceCount,
      completedAt: row.completedAt,
    }));
  }

  async createEvidencePackage(userId: string, dto: CreateEvidencePackageDto) {
    const groupId =
      dto.visibility === 'group' && dto.groupId ? dto.groupId : null;
    if (groupId) await this.groups.ensureMember(userId, groupId);
    const db = this.prisma as any;
    const pack = await db.evidencePackage.create({
      data: {
        userId,
        groupId,
        title: dto.title.trim(),
        courseName: dto.courseName?.trim() || null,
        description: dto.description?.trim() || null,
        sourceRefsJson: dto.sourceRefsJson,
        metricsJson: dto.metricsJson,
        coverImageUrl: dto.coverImageUrl ?? null,
        visibility: dto.visibility ?? 'private',
        featured: dto.featured ?? false,
      },
    });
    if (groupId) {
      await this.activities.create(userId, {
        type: 'evidencePackageShared',
        title: pack.title,
        summary: pack.description ?? undefined,
        groupId,
        sourceType: 'evidence_package',
        sourceId: pack.id,
        payloadJson: { courseName: pack.courseName, featured: pack.featured },
      });
    }
    return pack;
  }

  async listMyEvidencePackages(userId: string) {
    const db = this.prisma as any;
    return db.evidencePackage.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async listGroupEvidencePackages(userId: string, groupId: string) {
    await this.groups.ensureMember(userId, groupId);
    const db = this.prisma as any;
    return db.evidencePackage.findMany({
      where: { groupId, visibility: { in: ['group', 'public'] } },
      include: { user: { include: { profile: true } } },
      orderBy: [{ featured: 'desc' }, { createdAt: 'desc' }],
      take: 50,
    });
  }

  async updateEvidencePackage(userId: string, id: string, dto: UpdateEvidencePackageDto) {
    const db = this.prisma as any;
    const existing = await db.evidencePackage.findFirst({
      where: { id, userId },
    });
    if (!existing) throw new NotFoundException('evidence package not found');
    const nextVisibility = dto.visibility ?? existing.visibility;
    const nextGroupId =
      nextVisibility === 'group'
        ? (dto.groupId ?? existing.groupId)
        : null;
    if (nextGroupId) await this.groups.ensureMember(userId, nextGroupId);

    const updated = await db.evidencePackage.update({
      where: { id },
      data: {
        ...(dto.title != null ? { title: dto.title.trim() } : {}),
        ...(dto.description != null ? { description: dto.description.trim() || null } : {}),
        ...(dto.coverImageUrl != null ? { coverImageUrl: dto.coverImageUrl } : {}),
        ...(dto.visibility != null ? { visibility: dto.visibility } : {}),
        ...(dto.groupId !== undefined || dto.visibility != null ? { groupId: nextGroupId } : {}),
        ...(dto.featured != null ? { featured: dto.featured } : {}),
      },
    });
    if (nextGroupId && (!existing.groupId || existing.visibility !== 'group')) {
      await this.activities.create(userId, {
        type: 'evidencePackageShared',
        title: updated.title,
        summary: updated.description ?? undefined,
        groupId: nextGroupId,
        sourceType: 'evidence_package',
        sourceId: updated.id,
        payloadJson: { courseName: updated.courseName, featured: updated.featured },
      });
    }
    return updated;
  }

  async createLocationCheckIn(userId: string, dto: CreateLocationCheckInDto) {
    const groupId =
      dto.visibility === 'group' && dto.groupId ? dto.groupId : null;
    if (groupId) await this.groups.ensureMember(userId, groupId);
    const db = this.prisma as any;
    const checkIn = await db.locationCheckIn.create({
      data: {
        userId,
        groupId,
        title: dto.title.trim(),
        address: dto.address?.trim() || null,
        latitude: dto.latitude ?? null,
        longitude: dto.longitude ?? null,
        poiPayloadJson: dto.poiPayloadJson ?? null,
        visibility: dto.visibility ?? 'private',
      },
    });
    if (groupId) {
      await this.activities.create(userId, {
        type: 'locationCheckIn',
        title: checkIn.title,
        summary: checkIn.address ?? undefined,
        groupId,
        sourceType: 'location_check_in',
        sourceId: checkIn.id,
      });
    }
    return checkIn;
  }

  async listMyLocationCheckIns(userId: string) {
    const db = this.prisma as any;
    return db.locationCheckIn.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  private async ensureChallengeMember(userId: string, groupId: string, challengeId: string) {
    await this.groups.ensureMember(userId, groupId);
    const db = this.prisma as any;
    const challenge = await db.groupChallenge.findFirst({
      where: { id: challengeId, groupId },
    });
    if (!challenge) throw new NotFoundException('challenge not found');
    return challenge;
  }

  private withCounts(row: any) {
    return {
      ...row,
      participantCount: row.participations?.length ?? 0,
      evidenceCount: row.evidences?.length ?? 0,
      participations: undefined,
      evidences: undefined,
    };
  }
}
