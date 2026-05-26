import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser, CurrentUserPayload } from '../../common/current-user.decorator';
import { JwtAuthGuard } from '../../common/jwt-auth.guard';
import { CommunityEvidenceService } from './community-evidence.service';
import {
  AddChallengeEvidenceDto,
  ChallengeDraftDto,
  CreateChallengeDto,
  CreateEvidencePackageDto,
  CreateLocationCheckInDto,
  UpdateEvidencePackageDto,
} from './dto/community-evidence.dto';

@UseGuards(JwtAuthGuard)
@Controller()
export class CommunityEvidenceController {
  constructor(private readonly community: CommunityEvidenceService) {}

  @Post('groups/:id/challenges/ai-draft')
  draftChallenge(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') groupId: string,
    @Body() dto: ChallengeDraftDto,
  ) {
    return this.community.draftChallenge(user.userId, groupId, dto);
  }

  @Post('groups/:id/challenges')
  createChallenge(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') groupId: string,
    @Body() dto: CreateChallengeDto,
  ) {
    return this.community.createChallenge(user.userId, groupId, dto);
  }

  @Get('groups/:id/challenges')
  listChallenges(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') groupId: string,
  ) {
    return this.community.listChallenges(user.userId, groupId);
  }

  @Post('groups/:id/challenges/:challengeId/join')
  joinChallenge(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') groupId: string,
    @Param('challengeId') challengeId: string,
  ) {
    return this.community.joinChallenge(user.userId, groupId, challengeId);
  }

  @Post('groups/:id/challenges/:challengeId/evidence')
  addEvidence(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') groupId: string,
    @Param('challengeId') challengeId: string,
    @Body() dto: AddChallengeEvidenceDto,
  ) {
    return this.community.addChallengeEvidence(user.userId, groupId, challengeId, dto);
  }

  @Get('groups/:id/challenges/:challengeId/leaderboard')
  challengeLeaderboard(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') groupId: string,
    @Param('challengeId') challengeId: string,
  ) {
    return this.community.challengeLeaderboard(user.userId, groupId, challengeId);
  }

  @Post('evidence-packages')
  createEvidencePackage(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateEvidencePackageDto,
  ) {
    return this.community.createEvidencePackage(user.userId, dto);
  }

  @Get('evidence-packages/mine')
  listMine(@CurrentUser() user: CurrentUserPayload) {
    return this.community.listMyEvidencePackages(user.userId);
  }

  @Get('groups/:id/evidence-packages')
  listGroupPackages(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') groupId: string,
  ) {
    return this.community.listGroupEvidencePackages(user.userId, groupId);
  }

  @Patch('evidence-packages/:id')
  updatePackage(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') packageId: string,
    @Body() dto: UpdateEvidencePackageDto,
  ) {
    return this.community.updateEvidencePackage(user.userId, packageId, dto);
  }

  @Post('locations/check-ins')
  createLocationCheckIn(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateLocationCheckInDto,
  ) {
    return this.community.createLocationCheckIn(user.userId, dto);
  }

  @Get('locations/check-ins/mine')
  listMyLocationCheckIns(@CurrentUser() user: CurrentUserPayload) {
    return this.community.listMyLocationCheckIns(user.userId);
  }
}
