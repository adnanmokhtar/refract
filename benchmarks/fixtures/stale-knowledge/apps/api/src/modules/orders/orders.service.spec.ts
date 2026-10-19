import { OrdersService } from './orders.service';

describe('OrdersService', () => {
  it('flushes once when an order is placed', async () => {
    const em = { persistAndFlush: jest.fn(), flush: jest.fn(), find: jest.fn(), findOne: jest.fn() };
    const service = new OrdersService(em as never);
    await service.save({ id: 'o-1' } as never);
    expect(em.persistAndFlush).toHaveBeenCalledTimes(1);
    expect(em.flush).not.toHaveBeenCalled();
  });
});
