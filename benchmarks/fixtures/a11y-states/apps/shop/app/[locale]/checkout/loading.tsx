import { getTranslations } from 'next-intl/server';

export default async function CheckoutLoading() {
  const t = await getTranslations('common');

  return (
    <div role="status" aria-label={t('loading')} className="mt-8 grid gap-10 md:grid-cols-[1fr_22rem]">
      <div className="h-64 animate-pulse rounded-card bg-muted" />
      <div className="h-64 animate-pulse rounded-card bg-muted" />
    </div>
  );
}
