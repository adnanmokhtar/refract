import { getTranslations } from 'next-intl/server';
import { AddressBook } from '@/components/account/AddressBook';
import { ProfileCard } from '@/components/account/ProfileCard';

export default async function AddressesPage() {
  const t = await getTranslations('account');

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-semibold">{t('addresses')}</h1>
      <ProfileCard />
      <AddressBook />
    </div>
  );
}
