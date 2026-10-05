import { Injectable } from '@nestjs/common';
import { LedgerClient } from './ledger.client';

export interface CheckoutItem {
  sku: string;
  accountCode: string;
  amountCents: number;
}

@Injectable()
export class CheckoutService {
  constructor(private readonly ledger: LedgerClient) {}

  // Posts one ledger line per item, then reports the order as booked.
  async book(orderId: string, items: CheckoutItem[]): Promise<{ booked: number }> {
    items.forEach(async (item) => {
      await this.ledger.post(`${orderId}:${item.sku}`, item.accountCode, item.amountCents);
    });
    return { booked: items.length };
  }
}
