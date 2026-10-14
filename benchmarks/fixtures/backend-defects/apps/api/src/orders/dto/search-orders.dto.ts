import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class SearchOrdersDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  text?: string | null;

  @IsOptional()
  @IsIn(['open', 'paid', 'shipped', 'cancelled', 'refunded'])
  status?: string | null;
}
