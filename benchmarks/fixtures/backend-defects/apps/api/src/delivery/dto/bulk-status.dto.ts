import { ArrayMaxSize, IsIn } from 'class-validator';
import { Type } from 'class-transformer';
import { OrderRefDto } from './order-ref.dto';

export class BulkStatusDto {
  @IsIn(['dispatched', 'delivered', 'returned'])
  status!: string;

  @ArrayMaxSize(500)
  @Type(() => OrderRefDto)
  orders!: OrderRefDto[];
}
