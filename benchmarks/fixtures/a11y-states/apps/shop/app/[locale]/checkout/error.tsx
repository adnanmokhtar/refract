'use client';

import Link from 'next/link';
import { useTranslations } from 'next-intl';
import { Button } from '@/components/ui/Button';

export default function CheckoutError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const t = useTranslations('common');
  const tn = useTranslations('nav');

  return (
    <div role="alert" className="mx-auto mt-24 max-w-md text-center">
      <h1 className="text-xl font-semibold">{t('genericError')}</h1>
      <div className="mt-6 flex justify-center gap-3">
        <Button onClick={() => reset()}>{t('retry')}</Button>
        <Link href="/cart" className="inline-flex h-11 items-center rounded-lg px-5 text-sm hover:bg-muted">
          {tn('cart')}
        </Link>
      </div>
    </div>
  );
}
