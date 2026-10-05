import { Injectable } from '@nestjs/common';
import { ChargesService } from '../billing/charges.service';

export interface RefundItem {
  chargeId: string;
  amountCents: number;
}

@Injectable()
export class RefundBatchService {
  constructor(private readonly charges: ChargesService) {}

  // Refunds every item; the batch is reported done only when every refund has settled.
  async refundAll(items: RefundItem[]): Promise<string[]> {
    return Promise.all(items.map(async (item) => this.charges.refundCharge(item.chargeId, item.amountCents)));
  }
}
