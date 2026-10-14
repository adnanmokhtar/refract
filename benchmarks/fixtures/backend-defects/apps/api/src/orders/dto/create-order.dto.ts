import { ArrayMaxSize, ArrayMinSize, IsISO4217CurrencyCode, IsOptional, IsString, MaxLength, ValidateNested } from 'class-validator';
import { LineDto } from './line.dto';

export class CreateOrderDto {
  @IsISO4217CurrencyCode()
  currency!: string;

  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  lines!: LineDto[];

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string | null;
}
