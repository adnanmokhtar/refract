'use client';

import { useRouter } from 'next/navigation';
import { useTranslations } from 'next-intl';
import { api } from '@/lib/api';
import { useCart } from './useCart';

export function PlaceOrderButton() {
  const t = useTranslations('checkout');
  const router = useRouter();
  const { cart } = useCart();

  async function placeOrder(cartId: string) {
    const order = await api.post<{ id: string }>('/me/orders', { cartId });
    router.push(`/account/orders/${order.id}?placed=1`);
  }

  return (
    <button
      type="button"
      onClick={() => placeOrder(cart.id)}
      className="h-12 w-full rounded-lg bg-primary text-base font-semibold text-primary-foreground focus-visible:ring-2 focus-visible:ring-ring"
    >
      {t('placeOrder')}
    </button>
  );
}
