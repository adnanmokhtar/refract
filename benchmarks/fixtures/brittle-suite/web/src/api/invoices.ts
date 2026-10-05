// The API answers money as integer minor units: { id, number, totalCents, currency, lines: [...] }.
export interface InvoiceLineDto {
  description: string;
  quantity: number;
  unitCents: number;
}

export interface InvoiceDto {
  id: string;
  number: string;
  totalCents: number;
  currency: string;
  lines: InvoiceLineDto[];
}

export async function fetchInvoice(id: string): Promise<InvoiceDto> {
  const res = await fetch(`/api/invoices/${encodeURIComponent(id)}`);
  if (!res.ok) throw new Error(`invoice ${id}: ${res.status}`);
  return res.json();
}

export function formatMoney(cents: number, currency: string): string {
  return new Intl.NumberFormat('en-GB', { style: 'currency', currency }).format(cents / 100);
}
