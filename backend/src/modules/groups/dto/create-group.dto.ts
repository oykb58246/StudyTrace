import { IsOptional, IsString, Length } from 'class-validator';

export class CreateGroupDto {
  @IsString()
  @Length(1, 48)
  name: string;

  @IsOptional()
  @IsString()
  @Length(0, 160)
  description?: string;
}
