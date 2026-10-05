'use client';

import { useTranslations } from 'next-intl';
import { useProfile } from '@/lib/queries';

export function ProfileCard() {
  const t = useTranslations('account');
  const { data: me, isPending } = useProfile();

  if (isPending) return <div aria-busy="true" className="h-16 animate-pulse rounded-lg bg-stone-100" />;
  return (
    <section className="rounded-xl border p-4">
      <h2 className="font-semibold">{me?.name}</h2>
      <p className="text-sm text-stone-600">{me?.email}</p>
      <p className="text-xs text-stone-500">{t('profileHint')}</p>
    </section>
  );
}
