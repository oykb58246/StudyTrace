import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  Length,
} from 'class-validator';

export type MomentVisibility = 'private' | 'public' | 'includeGroups' | 'excludeGroups';

export class MomentVisibilityDto {
  @IsIn(['private', 'public', 'includeGroups', 'excludeGroups'])
  visibility: MomentVisibility;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(20)
  allowedGroupIds?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(20)
  deniedGroupIds?: string[];
}

export class CreateMomentDto extends MomentVisibilityDto {
  @IsString()
  @Length(1, 2000)
  content: string;

  @IsOptional()
  @IsString()
  @Length(0, 80)
  courseName?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(9)
  imagePaths?: string[];

  @IsOptional()
  @IsString()
  sourceType?: string;

  @IsOptional()
  @IsString()
  sourceId?: string;
}

export class CreateMomentCommentDto {
  @IsString()
  @Length(1, 500)
  content: string;
}
