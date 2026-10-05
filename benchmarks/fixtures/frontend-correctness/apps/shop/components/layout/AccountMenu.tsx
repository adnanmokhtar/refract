'use client';

import Link from 'next/link';
import { useTranslations } from 'next-intl';
import { useProfile } from '@/lib/queries';

export function AccountMenu() {
  const t = useTranslations('nav');
  const { data: me } = useProfile();

  return (
    <Link href="/account/orders" className="rounded-lg px-3 py-2 text-sm hover:bg-stone-100">
      {me ? me.name : t('account')}
    </Link>
  );
}
