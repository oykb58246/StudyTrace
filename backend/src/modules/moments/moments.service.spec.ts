import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { MomentsService } from './moments.service';

function serviceWithGroups(groupIds: string[]) {
  return new MomentsService({
    groupMember: {
      findMany: jest.fn().mockResolvedValue(
        groupIds.map((groupId) => ({ groupId })),
      ),
    },
  } as any);
}

function momentFixture(overrides: Record<string, any> = {}) {
  return {
    id: overrides.id ?? 'moment-1',
    userId: overrides.userId ?? 'user-1',
    content: overrides.content ?? '今天完成了一次学习记录',
    courseName: overrides.courseName ?? null,
    imagePathsJson: overrides.imagePathsJson ?? [],
    visibility: overrides.visibility ?? 'private',
    allowedGroupIds: overrides.allowedGroupIds ?? [],
    deniedGroupIds: overrides.deniedGroupIds ?? [],
    sourceType: overrides.sourceType ?? null,
    sourceId: overrides.sourceId ?? null,
    createdAt: overrides.createdAt ?? new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: overrides.updatedAt ?? new Date('2026-01-01T00:00:00.000Z'),
    user: overrides.user ?? {
      id: overrides.userId ?? 'user-1',
      username: 'student',
      profile: null,
      memberships: [],
    },
    likes: overrides.likes ?? [],
    comments: overrides.comments ?? [],
    _count: overrides._count ?? { likes: 0, comments: 0 },
  };
}

describe('MomentsService visibility rules', () => {
  it('keeps private moments author-only', () => {
    const service = serviceWithGroups([]);
    const canView = (service as any).canView.bind(service);
    const moment = {
      userId: 'author',
      visibility: 'private',
      user: { memberships: [{ groupId: 'g1' }] },
    };

    expect(canView(moment, 'author', [])).toBe(true);
    expect(canView(moment, 'viewer', ['g1'])).toBe(false);
  });

  it('treats public as author current groups only', () => {
    const service = serviceWithGroups([]);
    const canView = (service as any).canView.bind(service);
    const moment = {
      userId: 'author',
      visibility: 'public',
      user: { memberships: [{ groupId: 'g1' }] },
    };

    expect(canView(moment, 'viewer', ['g1'])).toBe(true);
    expect(canView(moment, 'viewer', ['g2'])).toBe(false);
  });

  it('allows include groups and lets excluded groups win', () => {
    const service = serviceWithGroups([]);
    const canView = (service as any).canView.bind(service);
    const includeMoment = {
      userId: 'author',
      visibility: 'includeGroups',
      allowedGroupIds: ['g2'],
      user: { memberships: [{ groupId: 'g2' }] },
    };
    const excludeMoment = {
      userId: 'author',
      visibility: 'excludeGroups',
      deniedGroupIds: ['g2'],
      user: { memberships: [{ groupId: 'g1' }, { groupId: 'g2' }] },
    };

    expect(canView(includeMoment, 'viewer', ['g2'])).toBe(true);
    expect(canView(includeMoment, 'viewer', ['g1'])).toBe(false);
    expect(canView(excludeMoment, 'viewer', ['g1'])).toBe(true);
    expect(canView(excludeMoment, 'viewer', ['g1', 'g2'])).toBe(false);
  });

  it('validates selected groups against author memberships', async () => {
    const service = serviceWithGroups(['g1', 'g2']);
    const normalize = (service as any).normalizeVisibility.bind(service);

    await expect(
      normalize('author', {
        visibility: 'includeGroups',
        allowedGroupIds: ['g1', 'g1'],
      }),
    ).resolves.toEqual({
      visibility: 'includeGroups',
      allowedGroupIds: ['g1'],
      deniedGroupIds: [],
    });

    await expect(
      normalize('author', {
        visibility: 'excludeGroups',
        deniedGroupIds: [],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    await expect(
      normalize('author', {
        visibility: 'includeGroups',
        allowedGroupIds: ['g3'],
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});

describe('MomentsService source type classification', () => {
  it('marks client-created moments as user posts by default', async () => {
    let savedMoment: any;
    const prisma = {
      groupMember: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      learningMoment: {
        create: jest.fn().mockImplementation(async ({ data }) => {
          savedMoment = momentFixture({ id: 'created-moment', ...data });
          return savedMoment;
        }),
        findUnique: jest.fn().mockImplementation(async () => savedMoment),
      },
    };
    const service = new MomentsService(prisma as any);

    const result = (await service.create('user-1', {
      content: '发布动态',
      visibility: 'private',
    })) as any;

    expect(prisma.learningMoment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ sourceType: 'user_post' }),
      }),
    );
    expect(result.sourceType).toBe('user_post');
    expect(result.momentKind).toBe('dynamic');
    expect(result.typeLabel).toBe('动态');
  });

  it('filters feed by dynamic and trace kinds', async () => {
    const moments = [
      momentFixture({ id: 'user-post', sourceType: 'user_post' }),
      momentFixture({ id: 'legacy-empty', sourceType: null }),
      momentFixture({ id: 'task-trace', sourceType: 'task_progress' }),
      momentFixture({ id: 'ai-trace', sourceType: 'ai_chat' }),
    ];
    const prisma = {
      groupMember: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      learningMoment: {
        findMany: jest.fn().mockResolvedValue(moments),
      },
    };
    const service = new MomentsService(prisma as any);

    await expect((service.feed as any)('user-1', 'dynamics')).resolves.toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'user-post', momentKind: 'dynamic' }),
        expect.objectContaining({ id: 'legacy-empty', momentKind: 'dynamic' }),
      ]),
    );
    await expect((service.feed as any)('user-1', 'dynamics')).resolves.toHaveLength(2);

    await expect((service.feed as any)('user-1', 'traces')).resolves.toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'task-trace', momentKind: 'trace' }),
        expect.objectContaining({ id: 'ai-trace', momentKind: 'trace' }),
      ]),
    );
    await expect((service.feed as any)('user-1', 'traces')).resolves.toHaveLength(2);
  });
});
