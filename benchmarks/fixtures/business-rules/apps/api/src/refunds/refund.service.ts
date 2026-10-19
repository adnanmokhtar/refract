import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { OrderLine } from '../orders/order-line.entity';
import { WalletPostingService } from '../wallets/wallet-posting.service';
import { StripeRefundGateway } from './stripe-refund.gateway';

export interface RefundDto {
  lineId: string;
  quantity: number;
  method: 'card' | 'wallet';
}

@Injectable()
export class RefundService {
  constructor(
    private readonly em: EntityManager,
    private readonly wallet: WalletPostingService,
    private readonly stripe: StripeRefundGateway,
  ) {}

  async refundLine(dto: RefundDto): Promise<number> {
    const line = await this.em.findOneOrFail(OrderLine, dto.lineId, { populate: ['order'] });
    const quantity = dto.quantity;
    const refundMinor = line.unitPriceMinor * quantity;
    if (dto.method === 'card') {
      await this.stripe.refund(line.order.id, refundMinor);
    } else {
      await this.wallet.post(line.order.customerId, refundMinor, { sourceType: 'refund', sourceId: line.id });
    }
    return refundMinor;
  }
}
