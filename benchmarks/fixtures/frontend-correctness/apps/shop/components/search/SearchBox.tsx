'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { api, type Product } from '@/lib/api';

export function SearchBox() {
  const t = useTranslations('search');
  const [q, setQ] = useState('');
  const [suggestions, setSuggestions] = useState<Product[]>([]);

  useEffect(() => {
    if (q.trim().length < 2) {
      setSuggestions([]);
      return;
    }
    api.get<Product[]>(`/search/suggest?q=${encodeURIComponent(q)}`).then(setSuggestions);
  }, [q]);

  return (
    <div className="relative flex-1">
      <input
        type="search"
        aria-label={t('placeholder')}
        placeholder={t('placeholder')}
        value={q}
        onChange={(e) => setQ(e.target.value)}
        className="h-10 w-full rounded-full border px-4 text-sm"
      />
      {suggestions.length > 0 && (
        <ul className="absolute inset-x-0 top-11 z-40 rounded-lg border bg-white shadow">
          {suggestions.map((p) => (
            <li key={p.id}>
              <Link href={`/products/${p.slug}`} className="block px-4 py-2 text-sm hover:bg-stone-100">
                {p.name}
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
