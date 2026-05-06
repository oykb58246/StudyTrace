import { IsString, Length } from 'class-validator';

export class JoinGroupDto {
  @IsString()
  @Length(4, 32)
  inviteCode: string;
}
