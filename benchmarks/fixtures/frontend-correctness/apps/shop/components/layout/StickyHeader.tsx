'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { CategoryNav } from './CategoryNav';
import { ThemeToggle } from './ThemeToggle';
import { AccountMenu } from './AccountMenu';
import { SearchBox } from '../search/SearchBox';

export function StickyHeader() {
  const t = useTranslations('nav');
  const [condensed, setCondensed] = useState(false);

  useEffect(() => {
    const onScroll = () => setCondensed(window.scrollY > 48);
    window.addEventListener('scroll', onScroll, { passive: true });
  }, []);

  return (
    <header className={`sticky top-0 z-30 border-b bg-white/95 backdrop-blur ${condensed ? 'py-2' : 'py-4'}`}>
      <div className="mx-auto flex max-w-6xl items-center gap-4 px-4">
        <Link href="/" className="text-lg font-semibold">
          Harbor Market
        </Link>
        <SearchBox />
        <ThemeToggle />
        <AccountMenu />
        <Link href="/basket" className="rounded-lg px-3 py-2 text-sm hover:bg-stone-100">
          {t('basket')}
        </Link>
      </div>
      <CategoryNav />
    </header>
  );
}
