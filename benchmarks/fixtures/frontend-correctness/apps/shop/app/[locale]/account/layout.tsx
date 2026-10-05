import Link from 'next/link';
import { getTranslations } from 'next-intl/server';
import { AccountGate } from '@/components/account/AccountGate';

export default async function AccountLayout({ children }: { children: React.ReactNode }) {
  const t = await getTranslations('account');

  return (
    <AccountGate>
      <div className="mt-8 grid gap-8 md:grid-cols-[12rem_1fr]">
        <nav aria-label={t('nav')}>
          <ul className="space-y-1 text-sm">
            <li>
              <Link href="/account">{t('overview')}</Link>
            </li>
            <li>
              <Link href="/account/orders">{t('orders')}</Link>
            </li>
            <li>
              <Link href="/account/addresses">{t('addresses')}</Link>
            </li>
          </ul>
        </nav>
        <div>{children}</div>
      </div>
    </AccountGate>
  );
}
