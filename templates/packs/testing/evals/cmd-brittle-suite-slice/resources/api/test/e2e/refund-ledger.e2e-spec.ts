import request from 'supertest';
import { asAgent, bootApp, BootedApp } from './boot-app.e2e';
import { seedDeliveredOrder, seedReturn } from '../support/factories';

// Posts refunds through to the Go payout ledger; needs the ledger's database.
const describeWithLedger = process.env.LEDGER_DATABASE_URL ? describe : describe.skip;

describeWithLedger('refund to ledger (e2e)', () => {
  let booted: BootedApp;

  beforeAll(async () => {
    booted = await bootApp();
  });

  it('debits the merchant balance by the refunded amount', async () => {
    const order = await seedDeliveredOrder(booted.app, { tenantId: 'tn_a', capturedCents: 3_000 });
    const ret = await seedReturn(booted.app, order, [{ sku: 'JAM-03', unitCents: 1_500, quantity: 2, opened: false }]);
    await request(booted.app.getHttpServer()).post(`/returns/${ret.id}/approve`).set(asAgent('tn_a')).send({ approver: 'a' }).expect(201);
    await request(booted.app.getHttpServer()).post(`/returns/${ret.id}/refund`).set(asAgent('tn_a')).expect(201);

    const balance = await fetch(`${process.env.LEDGER_URL}/balances/tn_a`).then((r) => r.json());
    expect(balance.pendingDebitCents).toBe(3_000);
  });
});
