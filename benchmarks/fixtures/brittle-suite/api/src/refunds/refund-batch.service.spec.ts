import { RefundBatchService, ReturnedOrder } from './refund-batch.service';
import { RefundService } from './refund.service';

const returnedOrder: ReturnedOrder = {
  orderId: 'ord_77',
  lines: [
    { lineId: 'line_1', unitCents: 2_500, quantity: 2, condition: 'damaged' },
    { lineId: 'line_2', unitCents: 1_200, quantity: 1, condition: 'kept' },
    { lineId: 'line_3', unitCents: 990, quantity: 1, condition: 'unopened' },
  ],
};

describe('RefundBatchService', () => {
  let refunds: { refund: jest.Mock };
  let batch: RefundBatchService;

  beforeEach(() => {
    refunds = { refund: jest.fn().mockResolvedValue({ id: 'rf_1', status: 'succeeded' }) };
    batch = new RefundBatchService(refunds as unknown as RefundService);
  });

  it('refunds every damaged or unopened line of a returned order', async () => {
    await batch.refundDamaged(returnedOrder);
  });

  it('leaves the lines the shopper kept out of the summary', async () => {
    const summary = await batch.refundDamaged(returnedOrder);
    expect(summary.refundedLines).toEqual(['line_1', 'line_3']);
  });
});
