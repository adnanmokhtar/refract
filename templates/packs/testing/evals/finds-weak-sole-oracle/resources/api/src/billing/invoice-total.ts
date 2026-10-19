export interface InvoiceLine {
  description: string;
  unitCents: number;
  quantity: number;
  taxRateBps: number; // basis points: 2000 = 20 %
}

export interface InvoiceTotal {
  netCents: number;
  taxCents: number;
  grossCents: number;
}

// Tax is computed per line and rounded half-up to the cent, as the merchant's invoice shows it.
export function computeInvoiceTotal(lines: InvoiceLine[]): InvoiceTotal {
  let netCents = 0;
  let taxCents = 0;
  for (const line of lines) {
    const net = line.unitCents * line.quantity;
    netCents += net;
    taxCents += Math.floor((net * line.taxRateBps + 5_000) / 10_000);
  }
  return { netCents, taxCents, grossCents: netCents + taxCents };
}

export function creditNoteTotal(original: InvoiceTotal, refundedNetCents: number, taxRateBps: number): InvoiceTotal {
  const taxCents = Math.floor((refundedNetCents * taxRateBps + 5_000) / 10_000);
  return { netCents: -refundedNetCents, taxCents: -taxCents, grossCents: -(refundedNetCents + taxCents) };
}
