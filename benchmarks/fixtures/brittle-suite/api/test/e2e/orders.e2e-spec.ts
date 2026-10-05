import request from 'supertest';
import { asAgent, bootApp, BootedApp } from './boot-app.e2e';
import { OrderRepository } from '../../src/orders/order.repository';

describe('orders (e2e)', () => {
  let booted: BootedApp;
  const delivered = {
    id: 'ord_100',
    number: 'R-1100',
    tenantId: 'tn_a',
    capturedCents: 5_200,
    refunds: { getItems: () => [{ amountCents: 1_200 }] },
  };

  beforeAll(async () => {
    booted = await bootApp((builder) =>
      builder.overrideProvider(OrderRepository).useValue({
        findOneOrFail: jest.fn().mockResolvedValue(delivered),
        findRecent: jest.fn().mockResolvedValue([delivered]),
      }),
    );
  });

  it('shows the refundable remainder of an order', async () => {
    const res = await request(booted.app.getHttpServer()).get('/orders/ord_100').set(asAgent('tn_a')).expect(200);
    expect(res.body).toEqual({
      id: 'ord_100',
      number: 'R-1100',
      capturedCents: 5_200,
      refundedCents: 1_200,
      refundableCents: 4_000,
    });
  });

  it('lists the recent orders of the agent tenant', async () => {
    const res = await request(booted.app.getHttpServer()).get('/orders').set(asAgent('tn_a')).expect(200);
    expect(res.body).toHaveLength(1);
  });
});
