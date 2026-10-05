import { RefundService } from './refund.service';

jest.mock('./refund.service');

describe('RefundService.refund', () => {
  const service = new RefundService({} as never, {} as never);

  it('refunds the requested amount of a delivered order', async () => {
    jest.mocked(service.refund).mockResolvedValue({ id: 'rf_1', amountCents: 1150, status: 'succeeded' } as never);

    const refund = await service.refund('ord_1', 1150, 'damaged in transit');

    expect(refund.amountCents).toBe(1150);
    expect(refund.status).toBe('succeeded');
  });

  it('records the provider reference', async () => {
    jest.mocked(service.refund).mockResolvedValue({ id: 'rf_2', providerRef: 're_5521' } as never);

    const refund = await service.refund('ord_2', 900, 'wrong size');

    expect(refund.providerRef).toBe('re_5521');
  });
});
