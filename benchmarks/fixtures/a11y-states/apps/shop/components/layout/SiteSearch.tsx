'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Search } from 'lucide-react';
import { useTranslations } from 'next-intl';

export function SiteSearch() {
  const t = useTranslations('search');
  const router = useRouter();
  const [q, setQ] = useState('');

  return (
    <form
      role="search"
      className="relative hidden flex-1 md:block"
      onSubmit={(e) => {
        e.preventDefault();
        router.push(`/search?q=${encodeURIComponent(q)}`);
      }}
    >
      <Search aria-hidden className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <input
        type="search"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={t('placeholder')}
        className="h-10 w-full rounded-full border bg-muted ps-9 pe-4 text-sm focus-visible:ring-2 focus-visible:ring-ring"
      />
    </form>
  );
}
