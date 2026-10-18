import { formatMoney } from '@acme/format';
import { t } from '@acme/i18n';

interface OrderSummaryCardProps {
  reference: string;
  totalMinor: number;
  currency: string;
  loading: boolean;
}

export function OrderSummaryCard({ reference, totalMinor, currency, loading }: OrderSummaryCardProps) {
  if (loading) return <p>{t('common.loading')}</p>;
  return (
    <div>
      <strong>{reference}</strong> {formatMoney(totalMinor, currency)}
    </div>
  );
}
