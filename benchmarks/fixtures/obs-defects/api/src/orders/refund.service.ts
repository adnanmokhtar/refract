import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PspClient } from '../payments/psp.client';
import { RefundRepository } from './refund.repository';

@Injectable()
export class RefundService {
  constructor(
    private readonly psp: PspClient,
    private readonly refunds: RefundRepository,
    @InjectPinoLogger(RefundService.name) private readonly logger: PinoLogger,
  ) {}

  async refund(orderId: string, amountCents: number): Promise<void> {
    try {
      const pspRefund = await this.psp.refund(orderId, amountCents);
      await this.refunds.record(orderId, amountCents, pspRefund.id);
    } catch (err) {
      this.logger.error({ error: err, orderId }, 'refund failed');
      throw err;
    }
  }

  async listForOrder(orderId: string) {
    return this.refunds.findByOrder(orderId);
  }

  async totalRefunded(orderId: string): Promise<number> {
    const rows = await this.refunds.findByOrder(orderId);
    return rows.reduce((sum, r) => sum + r.amountCents, 0);
  }

  async cancelPending(refundId: string): Promise<void> {
    try {
      await this.psp.cancelRefund(refundId);
      await this.refunds.markCancelled(refundId);
    } catch (err) {
      this.logger.error(err, 'cancel refund failed');
      throw err;
    }
  }
}
