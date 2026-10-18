import { t } from '@acme/i18n';
import type { OrderStatus } from '../types';
import styles from './OrderStatusBadge.module.css';

type OrderStatusBadgeProps = { status: OrderStatus };

function labelKey(status: OrderStatus): string {
  return `orders.status.${status}`;
}

export function OrderStatusBadge({ status }: OrderStatusBadgeProps) {
  return (
    <span className={styles.badge} style={{ color: status === 'failed' ? '#d92d20' : 'var(--color-text-muted)' }}>
      {t(labelKey(status))}
    </span>
  );
}
