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

class ThinkingEnabledDto {
  @IsOptional()
  @IsBoolean()
  thinkingEnabled?: boolean;
}

export class TextInputDto extends ThinkingEnabledDto {
  @IsString()
  input: string;
}

export class OcrDto {
  @IsString()
  imageBase64: string;
}

export class QueryRewriteDto {
  @IsString()
  query: string;
}

export class RerankDto {
  @IsString()
  query: string;

  @IsArray()
  @IsString({ each: true })
  sentences: string[];
}

export class WeeklyAnalysisDto extends ThinkingEnabledDto {
  @IsArray()
  logs: Record<string, unknown>[];

  @IsArray()
  tasks: Record<string, unknown>[];

  @IsDateString()
  startDate: string;

  @IsDateString()
  endDate: string;
}

export class RiskWarningsDto extends ThinkingEnabledDto {
  @IsArray()
  logs: Record<string, unknown>[];

  @IsArray()
  tasks: Record<string, unknown>[];
}

export class FlashCardsDto extends ThinkingEnabledDto {
  @IsArray()
  logs: Record<string, unknown>[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  count?: number;
}

export class WeeklyPlanDto extends ThinkingEnabledDto {
  @IsArray()
  tasks: Record<string, unknown>[];

  @IsArray()
  logs: Record<string, unknown>[];

  @IsArray()
  @IsString({ each: true })
  courses: string[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(14)
  days?: number;
}

export class LearningLoopDto extends ThinkingEnabledDto {
  @IsString()
  sourceText: string;

  @IsOptional()
  @IsString()
  imageBase64?: string;

  @IsOptional()
  @IsString()
  sourceKind?: 'photo' | 'voice' | 'text' | 'manual';

  @IsOptional()
  @IsString()
  target?: 'all' | 'task' | 'log' | 'note' | 'flashcard';

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  context?: string[];
}

export class RewriteDto extends ThinkingEnabledDto {
  @IsString()
  text: string;

  @IsString()
  intent: string;
}

export class FlashCardGradeDto extends ThinkingEnabledDto {
  @IsString()
  question: string;

  @IsString()
  correctAnswer: string;

  @IsString()
  userAnswer: string;

  @IsOptional()
  @IsString()
  courseName?: string;
}

export class ChatDto {
  @IsString()
  input: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
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
  @IsObject()
  options?: Record<string, unknown>;

  @IsOptional()
  @IsBoolean()
  thinkingEnabled?: boolean;
}

export class TranslateDto {
  @IsString()
  text: string;

  @IsOptional()
  @IsString()
  from?: string;

  @IsOptional()
  @IsString()
  to?: string;
}

export class ImageTaskSubmitDto {
  @IsString()
  prompt: string;

  @IsOptional()
  @IsString()
  initImageBase64?: string;

  @IsOptional()
  @IsString()
  styleConfig?: string;

  @IsOptional()
  @IsString()
  purpose?: string;

  @IsOptional()
  @IsInt()
  @Min(400)
  @Max(1200)
  width?: number;

  @IsOptional()
  @IsInt()
  @Min(400)
  @Max(1200)
  height?: number;
}

export class ImageTaskQueryDto {
  @IsString()
  taskId: string;
}

export class VideoTaskSubmitDto {
  @IsString()
  prompt: string;

  @IsOptional()
  @IsString()
  imageBase64?: string;

  @IsOptional()
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsString()
  model?: string;

  @IsOptional()
  @IsString()
  ratio?: string;

  @IsOptional()
  @IsString()
  resolution?: string;

  @IsOptional()
  @IsString()
  duration?: string;

  @IsOptional()
  @IsString()
  purpose?: string;
}

export class VideoTaskQueryDto {
  @IsString()
  taskId: string;
}

export class SpeechTranscribeDto {
  @IsString()
  audioBase64: string;

  @IsOptional()
  @IsString()
  mimeType?: string;

  @IsOptional()
  @IsString()
  mode?: 'short' | 'long';
}

export class EmbeddingIndexDto {
  @IsArray()
  items: Record<string, unknown>[];
}

export class EmbeddingSearchDto {
  @IsString()
  query: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  limit?: number;
}

export class PoiSearchDto {
  @IsString()
  query: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  location?: string;
}

export class ReverseGeocodeDto {
  @IsString()
  location: string;
}
