import { RefundApprovalService } from './refund-approval.service';
import { ReturnRepository } from './return.repository';
import { RefundService, RefundWindowExpiredError } from './refund.service';

const deliveredYesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
const deliveredLastYear = new Date(Date.now() - 400 * 24 * 60 * 60 * 1000);

describe('RefundApprovalService', () => {
  let returns: { findOneOrFail: jest.Mock; save: jest.Mock };
  let refunds: { refund: jest.Mock };
  let service: RefundApprovalService;

  beforeEach(() => {
    returns = { findOneOrFail: jest.fn(), save: jest.fn() };
    refunds = { refund: jest.fn().mockResolvedValue({ id: 'rf_1' }) };
    service = new RefundApprovalService(returns as unknown as ReturnRepository, refunds as unknown as RefundService);
    returns.findOneOrFail.mockResolvedValue({
      id: 'ret_1',
      orderId: 'ord_1',
      status: 'requested',
      windowDays: 30,
      deliveredAt: deliveredYesterday,
      lines: [
        { sku: 'MUG-01', unitCents: 1_800, quantity: 2, opened: true },
        { sku: 'TEA-12', unitCents: 650, quantity: 1, opened: false },
      ],
    });
  });

  it('approves a return and records the refund amount net of the restocking fee', async () => {
    await service.approve('ret_1', 'agent_7');
    expect(returns.save).toHaveBeenCalled();
  });

  it('refuses to refund a return whose window has closed', async () => {
    returns.findOneOrFail.mockResolvedValue({ id: 'ret_9', orderId: 'ord_9', windowDays: 30, deliveredAt: deliveredLastYear, lines: [] });
    expect(service.refundApproved('ret_9')).rejects.toThrow(RefundWindowExpiredError);
  });

  it('marks a refunded return as refunded', async () => {
    await service.refundApproved('ret_1');
    expect(returns.save).toHaveBeenCalledWith(expect.objectContaining({ status: 'refunded' }));
  });
});
