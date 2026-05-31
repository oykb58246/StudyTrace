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
