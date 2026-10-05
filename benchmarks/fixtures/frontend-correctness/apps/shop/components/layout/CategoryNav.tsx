import Link from 'next/link';
import { useTranslations } from 'next-intl';

const CATEGORIES = ['fruit', 'vegetables', 'bakery', 'dairy', 'pantry', 'drinks'] as const;

export function CategoryNav() {
  const t = useTranslations('categories');

  return (
    <nav aria-label={t('label')} className="mx-auto mt-2 flex max-w-6xl gap-2 overflow-x-auto px-4">
      {CATEGORIES.map((c) => (
        <Link key={c} href={`/c/${c}`} className="rounded-full border px-3 py-1 text-sm hover:bg-stone-100">
          <span className="inline-block w-[120px] truncate">{t(c)}</span>
        </Link>
      ))}
    </nav>
  );
}
