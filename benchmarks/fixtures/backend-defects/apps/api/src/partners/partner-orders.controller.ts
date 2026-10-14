import { Controller } from '@nestjs/common';
import { EventPattern, Payload } from '@nestjs/microservices';
import { IsInt, IsString, IsUUID, Min } from 'class-validator';

export class PartnerOrderDto {
  @IsString()
  partnerId!: string;

  @IsUUID()
  productId!: string;

  @IsInt()
  @Min(1)
  quantity!: number;
}

/** Orders that marketplace partners publish onto the shared Redis bus. */
@Controller()
export class PartnerOrdersController {
  @EventPattern('partner.order.created')
  async onPartnerOrder(@Payload() dto: PartnerOrderDto): Promise<void> {
    if (dto.quantity > 0) {
      // reserve stock and create the order
    }
  }
}
