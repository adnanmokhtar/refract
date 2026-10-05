import { OrdersService } from './orders.service';

describe('OrdersService.get', () => {
  it('fails when the order does not exist for the tenant', async () => {
    const orders = { findOne: jest.fn().mockResolvedValue(null) };
    const service = new OrdersService(orders as any);

    await expect(service.get('tn_1', 'ord_404')).rejects.toThrow();
  });
});

describe('OrdersService.recent', () => {
  const view = { id: 'ord_3', number: 'R-1003', capturedCents: 4_200, refundedCents: 0, refundableCents: 4_200 };

  it('lists the recent orders of the tenant', async () => {
    const service = new OrdersService({ findRecent: jest.fn().mockResolvedValue([{ id: 'ord_3' }]) } as never);
    jest.spyOn(service, 'get').mockResolvedValue(view);

    const result = await service.recent('tn_1');

    expect(result).toEqual([view]);
  });
});
