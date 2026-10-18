import { t } from '@acme/i18n';
import { OrderCard } from './components/OrderCard';
import { useOrders } from './useOrders';

export function OrdersPage() {
  const { data, isLoading } = useOrders();
  if (isLoading) return <p>{t('common.loading')}</p>;
  return (
    <section>
      <h1>{t('orders.title')}</h1>
      {data?.items.map((order) => <OrderCard key={order.id} order={order} />)}
    </section>
  );
}
