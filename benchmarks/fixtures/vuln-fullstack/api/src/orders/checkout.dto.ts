import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsInt, IsOptional, IsString, IsUUID, Min, ValidateNested } from 'class-validator';

export class CheckoutItemDto {
  @IsUUID()
  productId: string;

  @IsInt()
  @Min(1)
  quantity: number;

  // Shown in the cart line; sent back so the order matches what the buyer saw.
  @IsInt()
  @Min(0)
  unitPriceCents: number;
}

export class CheckoutDto {
  @IsUUID()
  sellerId: string;

  @ValidateNested({ each: true })
  @Type(() => CheckoutItemDto)
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  items: CheckoutItemDto[];

  @IsOptional()
  @IsString()
  couponCode?: string;
}
