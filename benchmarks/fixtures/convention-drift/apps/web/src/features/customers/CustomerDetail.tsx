import { t } from '@acme/i18n';
import { useCustomer } from './useCustomer';

type CustomerDetailProps = { customerId: string };

export function CustomerDetail({ customerId }: CustomerDetailProps) {
  const { data, isLoading } = useCustomer(customerId);
  if (isLoading || !data) return <p>{t('common.loading')}</p>;
  return (
    <dl>
      <dt>{t('customers.title')}</dt>
      <dd>{data.name}</dd>
      <dd>{data.email}</dd>
    </dl>
  );
}
