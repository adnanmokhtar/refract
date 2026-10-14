import { Injectable } from '@nestjs/common';
import { PspClient } from './psp.client';
import { toMinorUnits } from './psp-amount';

@Injectable()
export class RefundGateway {
  constructor(private readonly psp: PspClient) {}

  async refundInFull(orderId: string, amount: string, currency: string): Promise<void> {
    await this.psp.refund(`cap_${orderId}`, toMinorUnits(amount, currency));
  }
}
