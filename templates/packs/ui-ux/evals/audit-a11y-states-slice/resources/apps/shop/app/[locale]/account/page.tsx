import Link from 'next/link';
import { getTranslations, setRequestLocale } from 'next-intl/server';
import { getLoyalty, getRecentOrders, getRecommendations } from '@/lib/server-data';
import { formatDate, formatPrice } from '@/lib/format';
import { StoreCreditPanel } from '@/components/account/StoreCreditPanel';
import { GiftCardsPanel } from '@/components/account/GiftCardsPanel';
import { LoyaltyBadge } from '@/components/account/LoyaltyBadge';

export default async function AccountHome({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations('account');

  const [orders, loyalty, picks] = await Promise.all([getRecentOrders(), getLoyalty(), getRecommendations()]);

  return (
    <div className="space-y-10">
      <section aria-labelledby="loyalty-heading">
        <h2 id="loyalty-heading" className="text-lg font-semibold">
          {t('loyalty')}
        </h2>
        <LoyaltyBadge points={loyalty.points} tier={loyalty.tier} />
      </section>

      <section aria-labelledby="orders-heading">
        <h2 id="orders-heading" className="text-lg font-semibold">
          {t('orders')}
        </h2>
        <ul className="mt-3 divide-y">
          {orders.map((order) => (
            <li key={order.id} className="flex justify-between py-3 text-sm">
              <Link href={`/account/orders/${order.id}`}>{order.number}</Link>
              <span>{formatDate(order.placedAt, locale)}</span>
              <span className="tabular-nums">{formatPrice(order.total, locale)}</span>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="picks-heading">
        <h2 id="picks-heading" className="text-lg font-semibold">
          {t('recommended')}
        </h2>
        <ul className="mt-3 grid grid-cols-2 gap-4">
          {picks.map((p) => (
            <li key={p.id}>
              <Link href={`/products/${p.slug}`}>{p.name}</Link>
            </li>
          ))}
        </ul>
      </section>

      <StoreCreditPanel />
      <GiftCardsPanel />
    </div>
  );
}
