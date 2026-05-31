import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateMomentCommentDto,
  CreateMomentDto,
  MomentVisibilityDto,
} from './dto/moments.dto';

@Injectable()
export class MomentsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateMomentDto) {
    const normalized = await this.normalizeVisibility(userId, dto);
    const content = dto.content.trim();
    if (!content) {
      throw new BadRequestException('动态内容不能为空');
    }
    const db = this.prisma as any;
    const moment = await db.learningMoment.create({
      data: {
        userId,
        content,
        courseName: dto.courseName?.trim() || null,
        imagePathsJson: (dto.imagePaths ?? [])
          .map((item) => item.trim())
          .filter(Boolean)
          .slice(0, 9),
        visibility: normalized.visibility,
        allowedGroupIds: normalized.allowedGroupIds,
        deniedGroupIds: normalized.deniedGroupIds,
        sourceType: dto.sourceType?.trim() || null,
        sourceId: dto.sourceId?.trim() || null,
      },
    });
    return this.getVisibleSerialized(userId, moment.id);
  }

  async feed(userId: string) {
    const groupIds = await this.currentGroupIds(userId);
    const db = this.prisma as any;
    const where =
      groupIds.length === 0
        ? { userId }
        : {
            OR: [
              { userId },
              {
                visibility: 'public',
                user: {
                  memberships: {
                    some: { groupId: { in: groupIds }, leftAt: null },
                  },
                },
              },
              {
                visibility: 'includeGroups',
              },
              {
                visibility: 'excludeGroups',
                user: {
                  memberships: {
                    some: { groupId: { in: groupIds }, leftAt: null },
                  },
                },
              },
            ],
          };
    const moments = await db.learningMoment.findMany({
      where,
      include: this.momentInclude(userId),
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    return moments
      .filter((moment: any) => this.canView(moment, userId, groupIds))
      .slice(0, 80)
      .map((moment: any) => this.serialize(moment, userId));
  }

  async updateVisibility(userId: string, momentId: string, dto: MomentVisibilityDto) {
    const db = this.prisma as any;
    const existing = await db.learningMoment.findUnique({ where: { id: momentId } });
    if (!existing) throw new NotFoundException('动态不存在');
    if (existing.userId !== userId) throw new ForbiddenException('只能修改自己的动态权限');
    const normalized = await this.normalizeVisibility(userId, dto);
    await db.learningMoment.update({
      where: { id: momentId },
      data: {
        visibility: normalized.visibility,
        allowedGroupIds: normalized.allowedGroupIds,
        deniedGroupIds: normalized.deniedGroupIds,
      },
    });
    return this.getVisibleSerialized(userId, momentId);
  }

  async delete(userId: string, momentId: string) {
    const db = this.prisma as any;
    const existing = await db.learningMoment.findUnique({ where: { id: momentId } });
    if (!existing) throw new NotFoundException('动态不存在');
    if (existing.userId !== userId) throw new ForbiddenException('只能删除自己的动态');
    await db.learningMoment.delete({ where: { id: momentId } });
    return { ok: true };
  }

  async like(userId: string, momentId: string) {
    await this.findVisibleMoment(userId, momentId);
    const db = this.prisma as any;
    await db.learningMomentLike.upsert({
      where: { momentId_userId: { momentId, userId } },
      create: { momentId, userId },
      update: {},
    });
    return this.getVisibleSerialized(userId, momentId);
  }

  async unlike(userId: string, momentId: string) {
    await this.findVisibleMoment(userId, momentId);
    const db = this.prisma as any;
    await db.learningMomentLike.deleteMany({ where: { momentId, userId } });
    return this.getVisibleSerialized(userId, momentId);
  }

  async comment(userId: string, momentId: string, dto: CreateMomentCommentDto) {
    await this.findVisibleMoment(userId, momentId);
    const content = dto.content.trim();
    if (!content) {
      throw new BadRequestException('评论内容不能为空');
    }
    const db = this.prisma as any;
    await db.learningMomentComment.create({
      data: {
        momentId,
        userId,
        content,
      },
    });
    return this.getVisibleSerialized(userId, momentId);
  }

  async deleteComment(userId: string, momentId: string, commentId: string) {
    await this.findVisibleMoment(userId, momentId);
    const db = this.prisma as any;
    const comment = await db.learningMomentComment.findUnique({
      where: { id: commentId },
      include: { moment: true },
    });
    if (!comment || comment.momentId !== momentId) {
      throw new NotFoundException('评论不存在');
    }
    if (comment.userId !== userId && comment.moment.userId !== userId) {
      throw new ForbiddenException('只能删除自己的评论或自己动态下的评论');
    }
    await db.learningMomentComment.delete({ where: { id: commentId } });
    return this.getVisibleSerialized(userId, momentId);
  }

  private async getVisibleSerialized(userId: string, momentId: string) {
    const moment = await this.findVisibleMoment(userId, momentId);
    return this.serialize(moment, userId);
  }

  private async findVisibleMoment(userId: string, momentId: string) {
    const db = this.prisma as any;
    const moment = await db.learningMoment.findUnique({
      where: { id: momentId },
      include: this.momentInclude(userId),
    });
    if (!moment) throw new NotFoundException('动态不存在');
    const viewerGroupIds = await this.currentGroupIds(userId);
    if (!this.canView(moment, userId, viewerGroupIds)) {
      throw new ForbiddenException('没有权限查看该动态');
    }
    return moment;
  }

  private momentInclude(userId: string) {
    return {
      user: {
        include: {
          profile: true,
          memberships: { where: { leftAt: null }, select: { groupId: true } },
        },
      },
      likes: { where: { userId }, select: { id: true } },
      comments: {
        orderBy: { createdAt: 'desc' },
        take: 8,
        include: { user: { include: { profile: true } } },
      },
      _count: { select: { likes: true, comments: true } },
    };
  }

  private async normalizeVisibility(userId: string, dto: MomentVisibilityDto) {
    const visibility = dto.visibility;
    const allowedGroupIds = this.uniqueIds(dto.allowedGroupIds);
    const deniedGroupIds = this.uniqueIds(dto.deniedGroupIds);
    const ownGroupIds = await this.currentGroupIds(userId);
    const selected =
      visibility === 'includeGroups'
        ? allowedGroupIds
        : visibility === 'excludeGroups'
          ? deniedGroupIds
          : [];
    if (
      (visibility === 'includeGroups' || visibility === 'excludeGroups') &&
      selected.length === 0
    ) {
      throw new BadRequestException('请选择至少一个小组');
    }
    const invalid = selected.filter((groupId) => !ownGroupIds.includes(groupId));
    if (invalid.length > 0) {
      throw new ForbiddenException('只能选择自己已加入的小组');
    }
    return {
      visibility,
      allowedGroupIds: visibility === 'includeGroups' ? allowedGroupIds : [],
      deniedGroupIds: visibility === 'excludeGroups' ? deniedGroupIds : [],
    };
  }

  private uniqueIds(ids?: string[]) {
    return Array.from(
      new Set((ids ?? []).map((item) => item.trim()).filter(Boolean)),
    );
  }

  private async currentGroupIds(userId: string) {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId, leftAt: null },
      select: { groupId: true },
    });
    return memberships.map((item) => item.groupId);
  }

  private canView(moment: any, userId: string, viewerGroupIds: string[]) {
    if (moment.userId === userId) return true;
    if (moment.visibility === 'private') return false;
    const authorGroupIds =
      moment.user?.memberships?.map((item: { groupId: string }) => item.groupId) ?? [];
    if (moment.visibility === 'includeGroups') {
      return (
        this.hasOverlap(authorGroupIds, viewerGroupIds) &&
        this.hasOverlap(this.stringList(moment.allowedGroupIds), viewerGroupIds)
      );
    }
    const sameGroup = this.hasOverlap(authorGroupIds, viewerGroupIds);
    if (!sameGroup) return false;
    if (moment.visibility === 'excludeGroups') {
      return !this.hasOverlap(this.stringList(moment.deniedGroupIds), viewerGroupIds);
    }
    return moment.visibility === 'public';
  }

  private hasOverlap(left: string[], right: string[]) {
    return left.some((item) => right.includes(item));
  }

  private stringList(value: unknown) {
    return Array.isArray(value)
      ? value.filter((item): item is string => typeof item === 'string')
      : [];
  }

  private serialize(moment: any, viewerId: string) {
    const profile = moment.user?.profile;
    const comments = [...(moment.comments ?? [])].reverse().map((comment: any) => {
      const commentProfile = comment.user?.profile;
      return {
        id: comment.id,
        content: comment.content,
        createdAt: comment.createdAt,
        author: {
          id: comment.user?.id,
          username: comment.user?.username,
          nickname: commentProfile?.nickname ?? comment.user?.username ?? '学习者',
          avatarEmoji: commentProfile?.avatarEmoji ?? '🎓',
          avatarImageUrl: commentProfile?.avatarImageUrl ?? null,
        },
        isMine: comment.userId === viewerId,
      };
    });
    return {
      id: moment.id,
      content: moment.content,
      courseName: moment.courseName ?? '',
      imagePaths: this.stringList(moment.imagePathsJson),
      visibility: moment.visibility,
      allowedGroupIds: this.stringList(moment.allowedGroupIds),
      deniedGroupIds: this.stringList(moment.deniedGroupIds),
      sourceType: moment.sourceType,
      sourceId: moment.sourceId,
      createdAt: moment.createdAt,
      updatedAt: moment.updatedAt,
      author: {
        id: moment.user?.id,
        username: moment.user?.username,
        nickname: profile?.nickname ?? moment.user?.username ?? '学习者',
        avatarEmoji: profile?.avatarEmoji ?? '🎓',
        avatarImageUrl: profile?.avatarImageUrl ?? null,
      },
      likeCount: moment._count?.likes ?? 0,
      commentCount: moment._count?.comments ?? 0,
      likedByMe: (moment.likes ?? []).length > 0,
      comments,
      isMine: moment.userId === viewerId,
    };
  }
}
