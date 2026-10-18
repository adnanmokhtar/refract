import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../lib/api';
import { formatDate, formatMoney } from '../lib/format';
import { useUrlState } from '../lib/useUrlState';

interface InvoiceRow {
  id: number;
  number: string | null;
  status: string;
  total: string;
  issued_at: string | null;
}

export function InvoicesPage() {
  const { t } = useTranslation('orders');
  // Filters live in the URL, as V1's GET filter form did: Back and a shared link keep them.
  const [status, setStatus] = useUrlState<string[]>('status', []);
  const [rows, setRows] = useState<InvoiceRow[]>([]);

  useEffect(() => {
    void api.get<{ data: InvoiceRow[] }>('/invoices').then((r) => setRows(r.data.filter((i) => status.length === 0 || status.includes(i.status))));
  }, [status]);

  return (
    <main>
      <h1>{t('invoices_title')}</h1>
      <select multiple value={status} onChange={(e) => setStatus(Array.from(e.target.selectedOptions, (o) => o.value))}>
        {['issued', 'paid', 'void'].map((s) => (
          <option key={s} value={s}>
            {s}
          </option>
        ))}
      </select>
      <ul>
        {rows.map((i) => (
          <li key={i.id}>
            {i.number ?? '—'} · {formatDate(i.issued_at)} · {formatMoney(i.total, 'SAR')}
          </li>
        ))}
      </ul>
    </main>
  );
}
