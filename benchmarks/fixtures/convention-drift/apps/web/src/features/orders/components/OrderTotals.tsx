import { formatMoney } from '@acme/format';
import { t } from '@acme/i18n';

type OrderTotalsProps = { subtotalMinor: number; taxMinor: number; currency: string };

export function OrderTotals({ subtotalMinor, taxMinor, currency }: OrderTotalsProps) {
  return (
    <dl style={{ display: 'grid', gap: 'var(--space-2)', padding: '13px' }}>
      <dt>{t('cart.total')}</dt>
      <dd>{formatMoney(subtotalMinor + taxMinor, currency)}</dd>
    </dl>
  );
}
