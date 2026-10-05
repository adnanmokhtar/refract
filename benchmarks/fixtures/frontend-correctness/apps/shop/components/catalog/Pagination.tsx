'use client';

import Link from 'next/link';
import { usePathname, useSearchParams } from 'next/navigation';
import { useTranslations } from 'next-intl';

export function Pagination({ pages }: { pages: number }) {
  const t = useTranslations('catalog');
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const page = Number(searchParams.get('page') ?? 1);

  const href = (n: number) => {
    const next = new URLSearchParams(searchParams);
    next.set('page', String(n));
    return `${pathname}?${next}`;
  };

  return (
    <nav aria-label={t('pages')} className="mt-8 flex justify-center gap-4 text-sm">
      {page > 1 && <Link href={href(page - 1)}>{t('previous')}</Link>}
      <span>{t('pageOf', { page, pages })}</span>
      {page < pages && <Link href={href(page + 1)}>{t('next')}</Link>}
    </nav>
  );
}
