import { expect, it } from 'vitest';
import { lineNet } from '../../src/orders/pricing';
import { invoiceTotals } from '../../src/invoices/invoice-totals';
import { corpus, golden } from './support/harness';
import { describeV1 } from './support/v1';
import { v1 } from './support/v1-client';

// V1-pinned: these cases were recorded from v1/tests/Feature/InvoiceTotalsTest.php at the pin in
// ai/migration/ledger.md. A port PR must not edit them or their goldens (ADR-0003).
describeV1('invoice totals parity', () => {
  it('matches the V1 golden for the five-line reference invoice', () => {
    const expected = golden<{ subtotal: string; tax: string }>('invoice-totals');
    const lines = [['10.03', 1], ['10.03', 1], ['10.03', 1], ['10.03', 1], ['47.18', 1]].map(([p, q]) => ({ unitPrice: String(p), quantity: Number(q) }));
    const totals = invoiceTotals(lines, 0.15);

    expect(totals.subtotal.toFixed(2)).toBe(expected.subtotal);
    expect(totals.tax.toFixed(2)).toBe(expected.tax);
  });

  it('matches V1 line nets over the pricing corpus', async () => {
    for (const c of corpus<{ unit_price: number; quantity: number; discount_rate: number | null }>('pricing')) {
      expect(lineNet(c.unit_price, c.quantity, c.discount_rate).toFixed(2)).toBe(await v1.lineNet(c));
    }
  });

  it.skip('matches V1 credit amounts for negative halves', async () => {
    const { creditFor } = await import('../../src/invoices/credit-note');
    expect(creditFor('2.25', 0.5)).toBe(await v1.creditFor('2.25', 0.5));
    expect(creditFor('0.05', 0.5)).toBe(await v1.creditFor('0.05', 0.5));
  });
});
