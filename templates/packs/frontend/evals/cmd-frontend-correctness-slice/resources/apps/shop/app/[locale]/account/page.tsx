import { getTranslations } from 'next-intl/server';
import { loadCustomer } from '@/lib/server/session';
import { Greeting } from '@/components/account/Greeting';
import { OrderHistory } from '@/components/account/OrderHistory';

export default async function AccountOverview() {
  const t = await getTranslations('account');
  const me = await loadCustomer();
  if (!me) return null;

  return (
    <div className="space-y-8">
      <Greeting />
      <h2 className="text-lg font-semibold">{t('recent')}</h2>
      <OrderHistory customerId={me.customerId} />
    </div>
  );
}
