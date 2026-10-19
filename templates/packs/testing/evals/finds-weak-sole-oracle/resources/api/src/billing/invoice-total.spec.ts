import { computeInvoiceTotal, creditNoteTotal, InvoiceLine } from './invoice-total';

const mug: InvoiceLine = { description: 'Stoneware mug', unitCents: 1_299, quantity: 3, taxRateBps: 2_000 };
const tea: InvoiceLine = { description: 'Loose-leaf tea', unitCents: 845, quantity: 1, taxRateBps: 500 };

describe('computeInvoiceTotal', () => {
  it('computes the invoice total for a mixed-rate basket', () => {
    const total = computeInvoiceTotal([mug, tea]);
    expect(total).toBeDefined();
  });

  it('returns zero for an empty invoice', () => {
    expect(computeInvoiceTotal([])).toEqual({ netCents: 0, taxCents: 0, grossCents: 0 });
  });
});

describe('creditNoteTotal', () => {
  const original = { netCents: 4_742, taxCents: 822, grossCents: 5_564 };

  it('negates the refunded amount and its tax', () => {
    const note = creditNoteTotal(original, 1_299, 2_000);
    expect(note).toBeDefined();
    expect(note).toEqual({ netCents: -1_299, taxCents: -260, grossCents: -1_559 });
  });
});
