'use client';

import { useTranslations } from 'next-intl';
import { Button } from './Button';

export function ErrorState({ title, onRetry }: { title?: string; onRetry?: () => void }) {
  const t = useTranslations('common');

  return (
    <div role="alert" className="rounded-card border p-6 text-center">
      <p className="font-medium">{title ?? t('genericError')}</p>
      {onRetry && (
        <Button variant="secondary" className="mt-4" onClick={onRetry}>
          {t('retry')}
        </Button>
      )}
    </div>
  );
}
