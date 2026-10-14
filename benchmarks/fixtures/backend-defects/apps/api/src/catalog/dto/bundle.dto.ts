import { ArrayMaxSize, IsInt, IsString, IsUUID, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class BundleItemDto {
  @IsUUID()
  productId!: string;

  @IsInt()
  @Min(1)
  quantity!: number;
}

export class CreateBundleDto {
  @IsString()
  title!: string;

  @ArrayMaxSize(20)
  @ValidateNested()
  @Type(() => BundleItemDto)
  items!: BundleItemDto[];
}
