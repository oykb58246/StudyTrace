import { IsOptional, IsString, Length } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @Length(1, 32)
  nickname?: string;

  @IsOptional()
  @IsString()
  @Length(1, 16)
  avatarEmoji?: string;

  @IsOptional()
  @IsString()
  avatarImageUrl?: string;

  @IsOptional()
  @IsString()
  @Length(0, 160)
  bio?: string;
}
