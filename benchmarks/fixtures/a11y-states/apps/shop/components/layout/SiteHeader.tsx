'use client';

import Link from 'next/link';
import { useState } from 'react';
import { Menu, ShoppingBag } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { SiteSearch } from './SiteSearch';
import { PromoStrip } from './PromoStrip';

export function SiteHeader() {
  const t = useTranslations('nav');
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <>
      <PromoStrip />
      <header className="sticky top-0 z-40 h-20 border-b bg-background/95 backdrop-blur">
        <div className="mx-auto flex h-full max-w-6xl items-center gap-4 px-4">
          <button
            type="button"
            aria-label={t('home')}
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen((open) => !open)}
            className="grid size-11 place-items-center rounded-lg focus-visible:ring-2 focus-visible:ring-ring md:hidden"
          >
            <Menu aria-hidden className="size-5" />
          </button>
          <Link href="/" className="text-lg font-semibold tracking-tight">
            Lumen
          </Link>
          <SiteSearch />
          <nav aria-label={t('account')} className="ms-auto flex items-center gap-2">
            <Link href="/account" className="rounded-lg px-3 py-2 text-sm hover:bg-muted">
              {t('account')}
            </Link>
            <Link href="/cart" aria-label={t('cart')} className="grid size-11 place-items-center rounded-lg hover:bg-muted">
              <ShoppingBag aria-hidden className="size-5" />
            </Link>
          </nav>
        </div>
        {menuOpen && (
          <nav className="fixed inset-x-0 top-20 bottom-0 z-[9999] bg-background p-6 md:hidden">
            <ul className="space-y-4 text-lg">
              <li>
                <Link href="/">{t('home')}</Link>
              </li>
              <li>
                <Link href="/account">{t('account')}</Link>
              </li>
            </ul>
          </nav>
        )}
      </header>
    </>
  );
}
