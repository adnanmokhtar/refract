import { getTranslations } from 'next-intl/server';
import { BasketPanel } from '@/components/cart/BasketPanel';
import { CouponInput } from '@/components/checkout/CouponInput';
import { CheckoutSlots } from '@/components/checkout/CheckoutSlots';
import { HoldTimer } from '@/components/checkout/HoldTimer';

export default async function CheckoutPage() {
  const t = await getTranslations('checkout');

  return (
    <div className="mt-8 grid gap-10 md:grid-cols-[1fr_22rem]">
      <section>
        <h1 className="text-2xl font-semibold">{t('title')}</h1>
        <BasketPanel />
      </section>
      <aside className="space-y-6">
        <CheckoutSlots />
        <HoldTimer />
        <CouponInput />
        <button type="submit" form="checkout" className="h-12 w-full rounded-lg bg-brand font-semibold text-brand-foreground">
          {t('placeOrder')}
        </button>
      </aside>
    </div>
  );
}
