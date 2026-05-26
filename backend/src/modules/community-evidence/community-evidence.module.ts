import { Module } from '@nestjs/common';
import { ActivitiesModule } from '../activities/activities.module';
import { AiModule } from '../ai/ai.module';
import { GroupsModule } from '../groups/groups.module';
import { CommunityEvidenceController } from './community-evidence.controller';
import { CommunityEvidenceService } from './community-evidence.service';

@Module({
  imports: [GroupsModule, ActivitiesModule, AiModule],
  controllers: [CommunityEvidenceController],
  providers: [CommunityEvidenceService],
  exports: [CommunityEvidenceService],
})
export class CommunityEvidenceModule {}
