import { useState } from 'react';
import { del } from '../../lib/api-client';
import { t } from '../../lib/i18n';
import { Button } from '../ui/Button';
import type { Order } from '../../hooks/useOrders';

function formatMoney(cents: number): string {
  return `£${(cents / 100).toFixed(2)}`;
}

export function OrdersTable({ orders, onChanged }: { orders: Order[]; onChanged: () => void }) {
  const [busyId, setBusyId] = useState<string | null>(null);

  async function refund(order: Order) {
    setBusyId(order.id);
    await del(`/orders/${order.id}/charge`);
    setBusyId(null);
    onChanged();
  }

  if (orders.length === 0) {
    return <p style={{ padding: 'var(--space-4)' }}>No orders match this filter</p>;
  }

  return (
    <table style={{ width: '100%', borderCollapse: 'collapse' }}>
      <thead>
        <tr>
          <th style={{ textAlign: 'left', padding: 'var(--space-2)' }}>{t('orders.column.reference')}</th>
          <th style={{ textAlign: 'left', padding: 'var(--space-2)' }}>{t('orders.column.customer')}</th>
          <th style={{ textAlign: 'left', padding: 'var(--space-2)' }}>{t('orders.column.status')}</th>
          <th style={{ textAlign: 'right', padding: 'var(--space-2)' }}>{t('orders.column.total')}</th>
          <th />
        </tr>
      </thead>
      <tbody>
        {orders.map((order) => (
          <tr key={order.id} style={{ borderTop: '1px solid var(--color-border)' }}>
            <td style={{ padding: '13px' }}>{order.reference}</td>
            <td style={{ padding: 'var(--space-3)' }}>{order.customerEmail}</td>
            <td style={{ padding: 'var(--space-3)' }}>
              <span style={{ color: order.status === 'failed' ? '#d92d20' : 'var(--color-text-muted)' }}>
                {order.status}
              </span>
            </td>
            <td style={{ padding: 'var(--space-3)', textAlign: 'right' }}>
              {formatMoney(order.totalCents)}
            </td>
            <td style={{ padding: 'var(--space-3)', textAlign: 'right' }}>
              <button type="button" onClick={() => refund(order)} disabled={busyId === order.id}>
                ↩
              </button>
              <Button variant="danger" onClick={() => refund(order)}>
                {t('orders.action.refund')}
              </Button>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
