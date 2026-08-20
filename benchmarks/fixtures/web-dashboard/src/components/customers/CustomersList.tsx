import { useCustomers } from '../../hooks/useCustomers';
import { CustomerCard } from './CustomerCard';
import { t } from '../../lib/i18n';

// Reference consumer: renders all three states from the hook triple.
export function CustomersList() {
  const { data, loading, error } = useCustomers();

  if (loading) return <p>{t('common.loading')}</p>;
  if (error) return <p style={{ color: 'var(--color-danger)' }}>{t('customers.error')}</p>;
  if (data.length === 0) return <p>{t('customers.empty')}</p>;

  return (
    <div style={{ display: 'grid', gap: 'var(--space-3)', padding: 'var(--space-4)' }}>
      {data.map((customer) => (
        <CustomerCard key={customer.id} customer={customer} />
      ))}
    </div>
  );
}
