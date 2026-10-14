import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, IsISO4217CurrencyCode, IsNotEmpty, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { LineDto } from '../orders/dto/line.dto';

export class QuotePreviewDto {
  @ApiProperty()
  @IsISO4217CurrencyCode()
  currency!: string;

  @ApiProperty({ type: [LineDto] })
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => LineDto)
  lines!: LineDto[];

  @ApiPropertyOptional({ description: 'Partner reference echoed on the quote' })
  @IsNotEmpty()
  @IsString()
  partnerReference!: string;
}
