import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import { bootApp, paidOrder } from './helpers/app';

describe('refunds', () => {
  let app: NestFastifyApplication;
  beforeAll(async () => {
    app = await bootApp();
  });
  afterAll(() => app.close());

  it('AC-001 a full refund marks the order refunded', async () => {
    const order = await paidOrder(app);
    const res = await app.inject({ method: 'POST', url: `/api/orders/${order.id}/refunds`, payload: { lines: order.lines.map((l) => l.id), reason: 'damaged' } });
    expect(res.statusCode).toBe(201);
    expect(res.json().status).toBe('refunded');
  });

  it('AC-002 a partial refund keeps the order partially_refunded', async () => {
    const order = await paidOrder(app);
    const res = await app.inject({ method: 'POST', url: `/api/orders/${order.id}/refunds`, payload: { lines: [order.lines[0].id], reason: 'damaged' } });
    expect(res.json().status).toBe('partially_refunded');
  });

  it('AC-004 a gift-card order can be refunded', async () => {
    const order = await paidOrder(app, 1);
    const res = await app.inject({ method: 'POST', url: `/api/orders/${order.id}/refunds`, payload: { lines: [order.lines[0].id], reason: 'changed mind' } });
    expect(res.statusCode).toBe(201);
  });

  it('AC-006 the refund confirmation e-mail is queued', async () => {
    const order = await paidOrder(app);
    await app.inject({ method: 'POST', url: `/api/orders/${order.id}/refunds`, payload: { lines: [order.lines[0].id], reason: 'damaged' } });
    const outbox = await app.inject({ method: 'GET', url: '/api/test-support/outbox?template=refund-confirmation' });
    expect(outbox.json()).toHaveLength(1);
  });

  it('AC-009 a refund larger than the amount paid is rejected', async () => {
    const order = await paidOrder(app, 1);
    const res = await app.inject({ method: 'POST', url: `/api/orders/${order.id}/refunds`, payload: { lines: [order.lines[0].id, order.lines[0].id], reason: 'damaged' } });
    expect(res.statusCode).toBe(422);
  });
});
