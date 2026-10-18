import { formatDate, formatMoney } from '@acme/format';
import type { Order } from '../types';
import styles from './OrderCard.module.css';
import { OrderStatusBadge } from './OrderStatusBadge';

type OrderCardProps = { order: Order };

export function OrderCard({ order }: OrderCardProps) {
  return (
    <article className={styles.card}>
      <h3 className={styles.title}>{order.reference}</h3>
      <p className={styles.meta}>
        <span className={styles.dot} aria-hidden /> {formatDate(order.createdAt)} · {formatMoney(order.totalMinor, order.currency)}
      </p>
      <hr className={styles.divider} />
      <OrderStatusBadge status={order.status} />
    </article>
  );
}
