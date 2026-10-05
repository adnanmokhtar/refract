'use client';

import Link from 'next/link';
import { useTranslations } from 'next-intl';

export function RecentSearches() {
  const t = useTranslations('search');
  const recent: string[] = JSON.parse(localStorage.getItem('recent-searches') ?? '[]');

  if (recent.length === 0) return null;

  return (
    <section aria-labelledby="recent-searches">
      <h2 id="recent-searches" className="text-sm font-medium">
        {t('recent')}
      </h2>
      <ul className="mt-2 flex flex-wrap gap-2">
        {recent.map((term) => (
          <li key={term}>
            <Link href={`/search?q=${encodeURIComponent(term)}`} className="rounded-full border px-3 py-1 text-sm">
              {term}
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}
