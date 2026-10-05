import Link from 'next/link';
import { getTranslations } from 'next-intl/server';

const SECTIONS = ['orders', 'wishlist', 'profile', 'insights'] as const;

export default async function AccountLayout({ children }: { children: React.ReactNode }) {
  const t = await getTranslations('account');

  return (
    <div className="mt-8 grid gap-8 md:grid-cols-[12rem_1fr]">
      <nav aria-label={t('orders')}>
        <ul className="space-y-1">
          {SECTIONS.map((section) => (
            <li key={section}>
              <Link href={`/account/${section}`} className="block rounded-lg px-3 py-2 text-sm hover:bg-muted">
                {t(section)}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
      <div>{children}</div>
    </div>
  );
}
