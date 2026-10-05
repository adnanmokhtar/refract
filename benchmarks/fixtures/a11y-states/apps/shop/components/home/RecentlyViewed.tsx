'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useTranslations } from 'next-intl';
import { useRecentlyViewed } from '@/lib/queries';
import { Button } from '@/components/ui/Button';

export function RecentlyViewed() {
  const t = useTranslations('home');
  const tc = useTranslations('common');
  const { data, isError, refetch } = useRecentlyViewed();

  if (isError) {
    return (
      <section className="mt-16">
        <p className="text-sm text-muted-foreground">{tc('genericError')}</p>
        <Button variant="secondary" className="mt-3" onClick={() => refetch()}>
          {tc('retry')}
        </Button>
      </section>
    );
  }

  const items = data ?? [];

  return (
    <section className="mt-16" aria-labelledby="recent-heading">
      <h2 id="recent-heading" className="text-lg font-semibold">
        {t('recentlyViewed')}
      </h2>
      {items.length === 0 ? (
        <p className="mt-2 text-sm text-muted-foreground">{t('nothingViewed')}</p>
      ) : (
        <ul className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
          {items.map((p) => (
            <li key={p.id}>
              <Link href={`/products/${p.slug}`} className="block text-sm">
                <Image src={p.image} alt="" width={240} height={300} className="h-auto w-full rounded-lg" />
                <span className="mt-2 block">{p.name}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
