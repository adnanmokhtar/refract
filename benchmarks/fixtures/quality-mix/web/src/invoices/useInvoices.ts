import { useEffect, useState } from 'react';
import { api } from '../api/client';

export interface InvoiceRow {
  id: string;
  number: string;
  totalCents: number;
  issuedAt: string;
  status: 'open' | 'paid' | 'past_due' | 'void';
}

// The invoice list on the portal's billing page. An empty list renders "You have no invoices yet".
export function useInvoices(customerId: string) {
  const [rows, setRows] = useState<InvoiceRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    api<InvoiceRow[]>(`/customers/${customerId}/invoices`)
      .then((data) => {
        if (!cancelled) setRows(data);
      })
      .catch(() => setRows([]))
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [customerId]);

  return { rows, loading };
}
