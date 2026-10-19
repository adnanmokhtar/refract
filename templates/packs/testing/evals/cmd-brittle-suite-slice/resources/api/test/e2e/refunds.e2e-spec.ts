import request from 'supertest';
import { asAgent, bootApp, BootedApp } from './boot-app.e2e';
import { seedDeliveredOrder, seedReturn } from '../support/factories';

describe('returns and refunds (e2e)', () => {
  let booted: BootedApp;

  beforeAll(async () => {
    booted = await bootApp();
  });

  it('approves a return and refunds it through the provider', async () => {
    const order = await seedDeliveredOrder(booted.app, { tenantId: 'tn_a', capturedCents: 4_800 });
    const ret = await seedReturn(booted.app, order, [{ sku: 'MUG-01', unitCents: 2_400, quantity: 2, opened: false }]);

    await request(booted.app.getHttpServer())
      .post(`/returns/${ret.id}/approve`)
      .set(asAgent('tn_a'))
      .send({ approver: 'agent_7' })
      .expect(201);
    await request(booted.app.getHttpServer()).post(`/returns/${ret.id}/refund`).set(asAgent('tn_a')).expect(201);

    // the provider webhook lands through the outbox worker
    await new Promise((resolve) => setTimeout(resolve, 500));

    const res = await request(booted.app.getHttpServer()).get(`/orders/${order.id}`).set(asAgent('tn_a')).expect(200);
    expect(res.body.refundedCents).toBe(4_800);
  });

  it("hides another merchant's return", async () => {
    const order = await seedDeliveredOrder(booted.app, { tenantId: 'tn_a', capturedCents: 1_000 });
    const ret = await seedReturn(booted.app, order, [{ sku: 'TEA-12', unitCents: 1_000, quantity: 1, opened: false }]);

    await request(booted.app.getHttpServer())
      .post(`/returns/${ret.id}/approve`)
      .set(asAgent('tn_b'))
      .send({ approver: 'agent_9' })
      .expect(404);
    await request(booted.app.getHttpServer()).post(`/returns/${ret.id}/refund`).set(asAgent('tn_b')).expect(404);
  });

  it.skip('refunds a split-tender order to each tender — #812, owner @payments, remove by 2026-12-01', async () => {
    const order = await seedDeliveredOrder(booted.app, { tenantId: 'tn_a', capturedCents: 6_000 });
    const res = await request(booted.app.getHttpServer()).get(`/orders/${order.id}`).set(asAgent('tn_a')).expect(200);
    expect(res.body.refundableCents).toBe(6_000);
  });
});
