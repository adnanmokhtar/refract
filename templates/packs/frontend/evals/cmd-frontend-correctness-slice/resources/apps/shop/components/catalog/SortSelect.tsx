'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useTranslations } from 'next-intl';

const SORTS = ['relevance', 'price-asc', 'price-desc', 'newest'] as const;

export function SortSelect() {
  const t = useTranslations('catalog');
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const sort = searchParams.get('sort') ?? 'relevance';

  return (
    <label className="text-sm">
      {t('sort')}
      <select
        value={sort}
        onChange={(e) => {
          const next = new URLSearchParams(searchParams);
          next.set('sort', e.target.value);
          router.replace(`${pathname}?${next}`);
        }}
        className="ms-2 rounded-lg border px-2 py-1"
      >
        {SORTS.map((s) => (
          <option key={s} value={s}>
            {t(`sorts.${s}`)}
          </option>
        ))}
      </select>
    </label>
  );
}
