import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';

export class ChallengeDraftDto {
  @IsOptional()
  @IsArray()
  context?: string[];
}

export class CreateChallengeDto {
  @IsString()
  @Length(1, 80)
  title: string;

  @IsOptional()
  @IsString()
  @Length(0, 500)
  description?: string;

  @IsObject()
  planJson: Record<string, unknown>;

  @IsOptional()
  @IsObject()
  scoringJson?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  groupId?: string;

  @IsOptional()
  @IsString()
  coverImageUrl?: string;

  @IsOptional()
  @IsDateString()
  startsAt?: string;

  @IsOptional()
  @IsDateString()
  endsAt?: string;
}

export class AddChallengeEvidenceDto {
  @IsString()
  @Length(1, 40)
  evidenceType: string;

  @IsString()
  @Length(1, 120)
  title: string;

  @IsOptional()
  @IsString()
  @Length(0, 800)
  summary?: string;

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

export class CreateEvidencePackageDto {
  @IsString()
  @Length(1, 120)
  title: string;

  @IsOptional()
  @IsString()
  @Length(0, 80)
  courseName?: string;

  @IsOptional()
  @IsString()
  @Length(0, 1000)
  description?: string;

  @IsArray()
  sourceRefsJson: unknown[];

  @IsObject()
  metricsJson: Record<string, unknown>;

  @IsOptional()
  @IsString()
  groupId?: string;

  @IsOptional()
  @IsString()
  coverImageUrl?: string;

  @IsOptional()
  @IsIn(['private', 'group', 'public'])
  visibility?: 'private' | 'group' | 'public';

  @IsOptional()
  @IsBoolean()
  featured?: boolean;
}

export class UpdateEvidencePackageDto {
  @IsOptional()
  @IsString()
  @Length(1, 120)
  title?: string;

  @IsOptional()
  @IsString()
  @Length(0, 1000)
  description?: string;

  @IsOptional()
  @IsString()
  groupId?: string;

  @IsOptional()
  @IsString()
  coverImageUrl?: string;

  @IsOptional()
  @IsIn(['private', 'group', 'public'])
  visibility?: 'private' | 'group' | 'public';

  @IsOptional()
  @IsBoolean()
  featured?: boolean;
}

export class CreateLocationCheckInDto {
  @IsString()
  @Length(1, 120)
  title: string;

  @IsOptional()
  @IsString()
  @Length(0, 240)
  address?: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @IsOptional()
  @IsString()
  groupId?: string;

  @IsOptional()
  @IsObject()
  poiPayloadJson?: Record<string, unknown>;

  @IsOptional()
  @IsIn(['private', 'group'])
  visibility?: 'private' | 'group';
}
