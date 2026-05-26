import {
  IsDateString,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  Length,
} from 'class-validator';

export const activityTypes = [
  'taskCompleted',
  'subTaskCompleted',
  'studyLogCreated',
  'noteCreated',
  'flashcardBatchCreated',
  'timerCompleted',
  'dailyStreak',
  'momentShared',
  'challengeEvidence',
  'evidencePackageShared',
  'locationCheckIn',
  'voiceReview',
  'aiLoopApplied',
  'translatedMoment',
  'imageGenerated',
] as const;

export type ActivityType = (typeof activityTypes)[number];

export class CreateActivityDto {
  @IsIn(activityTypes)
  type: ActivityType;

  @IsString()
  @Length(1, 80)
  title: string;

  @IsOptional()
  @IsString()
  @Length(0, 240)
  summary?: string;

  @IsOptional()
  @IsString()
  groupId?: string;

  @IsOptional()
  @IsString()
  sourceType?: string;

  @IsOptional()
  @IsString()
  sourceId?: string;

  @IsOptional()
  @IsObject()
  payloadJson?: Record<string, unknown>;

  @IsOptional()
  @IsDateString()
  happenedAt?: string;
}
