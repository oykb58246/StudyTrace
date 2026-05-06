import {
  IsArray,
  IsDateString,
  IsObject,
  IsOptional,
  IsString,
  Length,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class SyncItemDto {
  @IsString()
  @Length(1, 64)
  entityType: string;

  @IsString()
  @Length(1, 128)
  entityId: string;

  @IsOptional()
  @IsObject()
  payloadJson?: Record<string, unknown>;

  @IsDateString()
  updatedAt: string;

  @IsOptional()
  @IsDateString()
  deletedAt?: string;
}

export class PushSyncDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncItemDto)
  items: SyncItemDto[];
}
