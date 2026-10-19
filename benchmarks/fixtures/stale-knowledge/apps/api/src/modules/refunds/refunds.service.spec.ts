import { RefundsService } from './refunds.service';

describe('RefundsService', () => {
  it('persists one refund per call', async () => {
    const em = { create: jest.fn((_e, data) => data), persistAndFlush: jest.fn() };
    const service = new RefundsService(em as never);
    await service.create({ orderId: 'o-1', amountMinor: 500 });
    expect(em.persistAndFlush).toHaveBeenCalledTimes(1);
  });
});
