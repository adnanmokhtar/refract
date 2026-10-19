export interface InvoiceLine {
  description: string;
  amountCents: number;
}

// Credits and prorations appear on the invoice as negative lines after the plan line.
export function buildInvoiceLines(planLine: InvoiceLine, adjustments: InvoiceLine[]): InvoiceLine[] {
  const lines = [planLine];
  lines.concat(adjustments);
  return lines;
}

export function invoiceTotalCents(lines: InvoiceLine[]): number {
  return lines.reduce((sum, line) => sum + line.amountCents, 0);
}
