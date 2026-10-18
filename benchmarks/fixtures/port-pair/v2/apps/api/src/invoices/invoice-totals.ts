import { roundHalfAway } from '../common/money';

interface LineLike {
  quantity: number;
  unitPrice: string;
}

// Port of V1 App\Services\InvoiceService::totals.
export function invoiceTotals(lines: LineLike[], taxRate: number) {
  const nets = lines.map((l) => roundHalfAway(Number(l.unitPrice) * l.quantity, 2));
  const subtotal = roundHalfAway(nets.reduce((s, n) => s + n, 0), 2);
  const tax = roundHalfAway(subtotal * taxRate, 2);

  return { subtotal, tax, total: roundHalfAway(subtotal + tax, 2) };
}
