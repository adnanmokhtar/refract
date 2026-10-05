import Link from 'next/link';
import { useTranslations } from 'next-intl';

export function PromoStrip() {
  const t = useTranslations('home');

  return (
    <aside aria-label={t('heroCta')} className="bg-[#0f766e] py-2 text-center text-sm text-primary-foreground">
      <Link href="/collections/autumn" className="underline underline-offset-4">
        {t('heroCta')}
      </Link>
    </aside>
  );
}
