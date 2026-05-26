import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ActivitiesModule } from './modules/activities/activities.module';
import { AiModule } from './modules/ai/ai.module';
import { AuthModule } from './modules/auth/auth.module';
import { GroupsModule } from './modules/groups/groups.module';
import { CommunityEvidenceModule } from './modules/community-evidence/community-evidence.module';
import { HealthModule } from './modules/health/health.module';
import { LeaderboardsModule } from './modules/leaderboards/leaderboards.module';
import { SyncModule } from './modules/sync/sync.module';
import { UsersModule } from './modules/users/users.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
    AuthModule,
    UsersModule,
    SyncModule,
    GroupsModule,
    CommunityEvidenceModule,
    ActivitiesModule,
    LeaderboardsModule,
    AiModule,
  ],
})
export class AppModule {}
