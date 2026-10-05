import { getTranslations, setRequestLocale } from 'next-intl/server';
import { ContactForm } from '@/components/checkout/ContactForm';
import { CouponField } from '@/components/checkout/CouponField';
import { PlaceOrderButton } from '@/components/checkout/PlaceOrderButton';
import { CheckoutSummary } from '@/components/checkout/CheckoutSummary';

export async function generateMetadata() {
  const t = await getTranslations('checkout');
  return { title: t('placeOrder') };
}

export default async function CheckoutPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations('checkout');

  return (
    <div className="mt-8 grid gap-10 md:grid-cols-[1fr_22rem]">
      <section aria-labelledby="contact-heading">
        <h1 id="contact-heading" className="text-2xl font-semibold">
          {t('contact')}
        </h1>
        <ContactForm />
      </section>
      <aside className="space-y-6">
        <CheckoutSummary />
        <CouponField />
        <PlaceOrderButton />
      </aside>
    </div>
  );
}
