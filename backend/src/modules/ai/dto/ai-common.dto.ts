import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class TextInputDto {
  @IsString()
  input: string;
}

export class WeeklyAnalysisDto {
  @IsArray()
  logs: Record<string, unknown>[];

  @IsArray()
  tasks: Record<string, unknown>[];

  @IsDateString()
  startDate: string;

  @IsDateString()
  endDate: string;
}

export class RiskWarningsDto {
  @IsArray()
  logs: Record<string, unknown>[];

  @IsArray()
  tasks: Record<string, unknown>[];
}

export class FlashCardsDto {
  @IsArray()
  logs: Record<string, unknown>[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  count?: number;
}

export class ChatDto {
  @IsString()
  input: string;

  @IsOptional()
  @IsArray()
  context?: string[];

  @IsOptional()
  @IsArray()
  messages?: Record<string, unknown>[];

  @IsOptional()
  @IsString()
  imageBase64?: string;

  @IsOptional()
  @IsString()
  purpose?: string;

  @IsOptional()
  @IsString()
  model?: string;

  @IsOptional()
  @IsString()
  provider?: 'blueheart' | 'deepseek';

  @IsOptional()
  @IsObject()
  options?: Record<string, unknown>;

  @IsOptional()
  @IsBoolean()
  thinkingEnabled?: boolean;
}
