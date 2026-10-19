import { IsArray, IsOptional, IsUUID } from 'class-validator';

export class ExportOrdersDto {
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  orderIds?: string[];
}
