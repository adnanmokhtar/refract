import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';
import { Type } from 'class-transformer';
import { PageQueryDto } from '../../common/page-query.dto';

export class ListCustomersQuery extends PageQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  q?: string;

  /** ?active=false lists churned customers for the win-back campaign. */
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  active?: boolean;
}
