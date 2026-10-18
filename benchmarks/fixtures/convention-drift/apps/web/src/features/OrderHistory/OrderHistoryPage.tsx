import { useEffect } from 'react';
import { notify } from '@acme/ui';
import { formatDate, formatMoney } from '@acme/format';
import { t } from '@acme/i18n';
import { ReportTable } from '@acme/legacy-reports';
import { useOrderHistory } from './useOrderHistory';

interface OrderHistoryPageProps {
  customerId: string;
}

export function OrderHistoryPage({ customerId }: OrderHistoryPageProps) {
  const { data, error } = useOrderHistory(customerId);

  useEffect(() => {
    if (error) notify({ kind: 'error', message: t('history.loadFailed') });
  }, [error]);

  const rows = (data ?? []).map((o) => ({ id: o.id, label: formatDate(o.createdAt), value: formatMoney(o.totalMinor, o.currency) }));
  return (
    <section>
      <h1>{t('history.title')}</h1>
      <ReportTable rows={rows} />
    </section>
  );
}
