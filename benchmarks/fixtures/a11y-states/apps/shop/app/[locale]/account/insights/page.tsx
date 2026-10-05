import { getTranslations, setRequestLocale } from 'next-intl/server';
import { InsightsTabs } from '@/components/account/InsightsTabs';

export async function generateMetadata() {
  const t = await getTranslations('account');
  return { title: t('insights') };
}

export default async function InsightsPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations('account');

  return (
    <div>
      <h1 className="text-2xl font-semibold">{t('insights')}</h1>
      <InsightsTabs />
    </div>
  );
}
