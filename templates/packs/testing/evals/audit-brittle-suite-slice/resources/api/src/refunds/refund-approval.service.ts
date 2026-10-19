import { Injectable } from '@nestjs/common';
import { ReturnRepository } from './return.repository';
import { ReturnRequest } from './return-request.entity';
import { RefundService, RefundWindowExpiredError } from './refund.service';
import { DAY_MS } from './refund-window';

export const RESTOCKING_FEE_CENTS = 500;

@Injectable()
export class RefundApprovalService {
  constructor(
    private readonly returns: ReturnRepository,
    private readonly refunds: RefundService,
  ) {}

  // An opened item carries the merchant's restocking fee; the fee is taken once per return.
  async approve(returnId: string, approver: string): Promise<ReturnRequest> {
    const request = await this.returns.findOneOrFail(returnId);
    const gross = request.lines.reduce((sum, line) => sum + line.unitCents * line.quantity, 0);
    const restocking = request.lines.some((line) => line.opened) ? RESTOCKING_FEE_CENTS : 0;
    request.refundCents = Math.max(0, gross - restocking);
    request.status = 'approved';
    request.approvedBy = approver;
    await this.returns.save(request);
    return request;
  }

  async refundApproved(returnId: string): Promise<void> {
    const request = await this.returns.findOneOrFail(returnId);
    if (Date.now() > request.deliveredAt.getTime() + request.windowDays * DAY_MS) {
      throw new RefundWindowExpiredError(request.orderId, `${request.windowDays} days`);
    }
    await this.refunds.refund(request.orderId, request.refundCents ?? 0, `return:${request.id}`);
    request.status = 'refunded';
    await this.returns.save(request);
  }
}
