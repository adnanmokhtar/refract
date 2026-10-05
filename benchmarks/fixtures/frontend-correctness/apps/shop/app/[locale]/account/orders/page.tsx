import { getTranslations } from 'next-intl/server';
import { getAddresses, getOrders } from '@/lib/server/account';
import { OrdersTable } from '@/components/account/OrdersTable';
import { OrderTracker } from '@/components/account/OrderTracker';
import { ReorderButton } from '@/components/account/ReorderButton';

export default async function OrdersPage() {
  const t = await getTranslations('account');
  const orders = await getOrders();
  const addresses = await getAddresses();
  const active = orders.find((o) => o.status !== 'delivered');

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-semibold">{t('orders')}</h1>
      {active && (
        <section className="rounded-xl border p-4">
          <OrderTracker orderId={active.id} />
          <p className="text-sm text-stone-600">{t('deliveringTo', { address: addresses[0]?.line1 ?? '' })}</p>
        </section>
      )}
      <OrdersTable orders={orders} />
      {orders[0] && <ReorderButton orderId={orders[0].id} />}
    </div>
  );
}
