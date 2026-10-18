import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ORDER_STATUSES } from '@norrow/contracts';
import { api } from '../lib/api';
import { formatMoney } from '../lib/format';
import { useUrlState } from '../lib/useUrlState';

const FILTERABLE = ORDER_STATUSES.filter((s) => s !== 'draft' && s !== 'refunded');

interface OrderRow {
  id: number;
  number: string;
  status: string;
  currency: string;
  total: string;
}

export function OrdersPage() {
  const { t } = useTranslation('orders');
  const [page, setPage] = useUrlState<string>('page', '1');
  const [status, setStatus] = useState<string[]>([]);
  const [rows, setRows] = useState<OrderRow[]>([]);

  useEffect(() => {
    const qs = new URLSearchParams({ page, per_page: '25' });
    status.forEach((s) => qs.append('status', s));
    void api.get<{ data: OrderRow[] }>(`/orders?${qs}`).then((r) => setRows(r.data));
  }, [page, status]);

  const toggle = (s: string) => setStatus(status.includes(s) ? status.filter((x) => x !== s) : [...status, s]);

  return (
    <main>
      <h1>{t('title')}</h1>
      <fieldset className="filters">
        {FILTERABLE.map((s) => (
          <label key={s}>
            <input type="checkbox" checked={status.includes(s)} onChange={() => toggle(s)} />
            {t(`status_${s}`)}
          </label>
        ))}
      </fieldset>
      {rows.length === 0 ? (
        <p className="empty">{t('items', { count: 0 })}</p>
      ) : (
        <ul>
          {rows.map((o) => (
            <li key={o.id}>
              {o.number} · {t(`status_${o.status}`)} · {formatMoney(o.total, o.currency)}
            </li>
          ))}
        </ul>
      )}
      <button type="button" onClick={() => setPage(String(Number(page) + 1))}>
        {t('next_page')}
      </button>
    </main>
  );
}
