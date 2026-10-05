'use client';

import { useState } from 'react';
import { Moon, Sun } from 'lucide-react';
import { useTranslations } from 'next-intl';

const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

export function ThemeToggle() {
  const t = useTranslations('nav');
  const [dark, setDark] = useState(prefersDark);

  function toggle() {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle('dark', next);
  }

  return (
    <button type="button" aria-label={t('theme')} aria-pressed={dark} onClick={toggle} className="grid size-10 place-items-center rounded-lg">
      {dark ? <Sun aria-hidden className="size-5" /> : <Moon aria-hidden className="size-5" />}
    </button>
  );
}
