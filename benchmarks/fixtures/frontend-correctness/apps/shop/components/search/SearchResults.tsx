'use client';

import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { useTranslations } from 'next-intl';
import { api, type Product } from '@/lib/api';

export function SearchResults() {
  const t = useTranslations('search');
  const searchParams = useSearchParams();
  const q = searchParams.get('q') ?? '';
  const { data, isPending, isError } = useQuery({
    queryKey: ['search', q],
    queryFn: ({ signal }) => api.get<Product[]>(`/search?q=${encodeURIComponent(q)}`, { signal }),
    enabled: q.length > 0,
  });

  if (!q) return null;
  if (isPending) return <p aria-busy="true">{t('searching')}</p>;
  if (isError) return <p role="alert">{t('error')}</p>;
  if (data.length === 0) return <p>{t('noResults')}</p>;

  return (
    <ul className="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
      {data.map((p) => (
        <li key={p.id}>
          <Link href={`/products/${p.slug}`}>{p.name}</Link>
        </li>
      ))}
    </ul>
  );
}
