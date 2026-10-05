import { getTranslations, setRequestLocale } from 'next-intl/server';
import { OrdersPanel } from '@/components/account/OrdersPanel';

export async function generateMetadata() {
  const t = await getTranslations('account');
  return { title: t('orders') };
}

export default async function OrdersPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <OrdersPanel />;
}
