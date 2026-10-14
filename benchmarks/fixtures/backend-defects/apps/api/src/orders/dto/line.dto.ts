import { IsInt, IsString, IsUUID, Max, Min } from 'class-validator';

export class LineDto {
  @IsUUID()
  productId!: string;

  @IsString()
  sku!: string;

  @IsInt()
  @Min(1)
  @Max(999)
  quantity!: number;
}
