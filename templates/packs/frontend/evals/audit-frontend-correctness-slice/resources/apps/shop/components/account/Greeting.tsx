import { getTranslations } from 'next-intl/server';
import { customer } from '@/lib/server/session';

export async function Greeting() {
  const t = await getTranslations('account');
  const me = customer();

  return <h1 className="text-2xl font-semibold">{t('hello', { name: me?.name ?? '' })}</h1>;
}
