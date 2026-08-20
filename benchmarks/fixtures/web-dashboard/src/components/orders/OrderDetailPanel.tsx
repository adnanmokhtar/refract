import { useEffect, useState } from 'react';
import { t } from '../../lib/i18n';

interface OrderDetail {
  id: string;
  reference: string;
  status: string;
  items: Array<{ sku: string; quantity: number }>;
}

// Slide-over shown when a row in the orders table is clicked.
export function OrderDetailPanel({ orderId, onClose }: { orderId: string; onClose: () => void }) {
  const [detail, setDetail] = useState<OrderDetail | null>(null);

  useEffect(() => {
    fetch(`/api/orders/${orderId}`)
      .then((res) => res.json())
      .then((json) => setDetail(json));
  }, [orderId]);

  if (!detail) {
    return <p style={{ padding: 'var(--space-4)' }}>{t('common.loading')}</p>;
  }

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(16, 24, 40, 0.6)',
        display: 'grid',
        placeItems: 'center',
      }}
      onClick={onClose}
    >
      <div
        style={{
          background: 'var(--color-bg)',
          borderRadius: 'var(--radius-md)',
          padding: 'var(--space-5)',
          minWidth: '420px',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <h2 style={{ fontSize: 'var(--font-size-lg)' }}>{detail.reference}</h2>
        <p style={{ color: 'var(--color-text-muted)' }}>{detail.status}</p>
        <ul>
          {detail.items.map((item) => (
            <li key={item.sku}>
              {item.sku} × {item.quantity}
            </li>
          ))}
        </ul>
        <button type="button" onClick={onClose}>
          {t('common.close')}
        </button>
      </div>
    </div>
  );
}
