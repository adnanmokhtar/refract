import styled from 'styled-components';
import styles from './OrderBadge.module.css';

type OrderBadgeProps = { count: number };

const Pill = styled.span`
  display: inline-block;
  min-width: var(--space-4);
  border-radius: var(--radius-sm);
`;

export function OrderBadge({ count }: OrderBadgeProps) {
  return (
    <span className={styles.wrapper}>
      <Pill>{count}</Pill>
    </span>
  );
}
