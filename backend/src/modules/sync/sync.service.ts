import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PushSyncDto, SyncItemDto } from './dto/push-sync.dto';

@Injectable()
export class SyncService {
  constructor(private readonly prisma: PrismaService) {}

  async push(userId: string, dto: PushSyncDto) {
    const results: unknown[] = [];
    for (const item of dto.items) {
      results.push(await this.upsertItem(userId, item));
    }
    return { results };
  }

  async pull(userId: string, cursor?: string) {
    const since = cursor ? new Date(cursor) : new Date(0);
    const items = await this.prisma.syncItem.findMany({
      where: {
        userId,
        serverUpdatedAt: { gt: since },
      },
      orderBy: { serverUpdatedAt: 'asc' },
    });
    const nextCursor =
      items.length > 0
        ? items[items.length - 1].serverUpdatedAt.toISOString()
        : cursor ?? new Date(0).toISOString();

    return {
      nextCursor,
      items: items.map((item) => this.serialize(item)),
    };
  }

  async exportAll(userId: string) {
    const items = await this.prisma.syncItem.findMany({
      where: { userId },
      orderBy: [{ entityType: 'asc' }, { updatedAt: 'asc' }],
    });
    return { items: items.map((item) => this.serialize(item)) };
  }

  private async upsertItem(userId: string, item: SyncItemDto) {
    const incomingUpdatedAt = new Date(item.updatedAt);
    const incomingDeletedAt = item.deletedAt ? new Date(item.deletedAt) : null;
    const existing = await this.prisma.syncItem.findUnique({
      where: {
        userId_entityType_entityId: {
          userId,
          entityType: item.entityType,
          entityId: item.entityId,
        },
      },
    });

    if (existing && incomingUpdatedAt.getTime() < existing.updatedAt.getTime()) {
      return {
        entityType: item.entityType,
        entityId: item.entityId,
        status: 'skipped_older',
        serverUpdatedAt: existing.serverUpdatedAt,
      };
    }

    const payloadJson = (item.payloadJson ?? existing?.payloadJson ?? {}) as Prisma.InputJsonValue;
    const saved = existing
      ? await this.prisma.syncItem.update({
          where: { id: existing.id },
          data: {
            payloadJson,
            updatedAt: incomingUpdatedAt,
            deletedAt: incomingDeletedAt,
          },
        })
      : await this.prisma.syncItem.create({
          data: {
            userId,
            entityType: item.entityType,
            entityId: item.entityId,
            payloadJson,
            updatedAt: incomingUpdatedAt,
            deletedAt: incomingDeletedAt,
          },
        });

    return {
      entityType: saved.entityType,
      entityId: saved.entityId,
      status: existing ? 'updated' : 'created',
      serverUpdatedAt: saved.serverUpdatedAt,
    };
  }

  private serialize(item: {
    entityType: string;
    entityId: string;
    payloadJson: Prisma.JsonValue;
    updatedAt: Date;
    deletedAt: Date | null;
    serverUpdatedAt: Date;
  }) {
    return {
      entityType: item.entityType,
      entityId: item.entityId,
      payloadJson: item.payloadJson,
      updatedAt: item.updatedAt.toISOString(),
      deletedAt: item.deletedAt?.toISOString() ?? null,
      serverUpdatedAt: item.serverUpdatedAt.toISOString(),
    };
  }
}
