import { IsUUID } from 'class-validator';

export class OrderRefDto {
  @IsUUID()
  orderId!: string;
}
