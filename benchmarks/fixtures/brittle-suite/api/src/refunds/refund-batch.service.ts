import { Injectable } from '@nestjs/common';
import { RefundService } from './refund.service';

export interface ReturnedLine {
  lineId: string;
  unitCents: number;
  quantity: number;
  condition: 'damaged' | 'unopened' | 'kept';
}

export interface ReturnedOrder {
  orderId: string;
  lines: ReturnedLine[];
}

export interface BatchSummary {
  refundedLines: string[];
  refundedCents: number;
}

@Injectable()
export class RefundBatchService {
  constructor(private readonly refunds: RefundService) {}

  // Damaged and unopened lines are refunded in full; lines the shopper kept are not refunded.
  async refundDamaged(order: ReturnedOrder): Promise<BatchSummary> {
    const summary: BatchSummary = { refundedLines: [], refundedCents: 0 };
    for (const line of order.lines) {
      if (line.condition === 'kept') continue;
      const cents = line.unitCents * line.quantity;
      await this.refunds.refund(order.orderId, cents, `return:${line.lineId}:${line.condition}`);
      summary.refundedLines.push(line.lineId);
      summary.refundedCents += cents;
    }
    return summary;
  }
}
