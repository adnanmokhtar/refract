import { ArrayMaxSize, IsOptional, IsString, IsUUID, MaxLength, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class CollectionItemDto {
  @IsUUID()
  productId!: string;
}

export class WriteCollectionDto {
  @IsString()
  @MaxLength(80)
  title!: string;

  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => CollectionItemDto)
  items!: CollectionItemDto[];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string | null;
}
