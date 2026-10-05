'use client';

import { useTranslations } from 'next-intl';
import { Button } from '@/components/ui/Button';

export default function StorefrontError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const t = useTranslations('common');

  return (
    <div role="alert" className="mx-auto mt-24 max-w-md text-center">
      <h1 className="text-xl font-semibold">{t('genericError')}</h1>
      <Button className="mt-6" onClick={() => reset()}>
        {t('retry')}
      </Button>
    </div>
  );
}
