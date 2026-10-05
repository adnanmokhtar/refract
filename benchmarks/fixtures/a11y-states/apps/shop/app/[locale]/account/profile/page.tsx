import { getTranslations, setRequestLocale } from 'next-intl/server';
import { ProfileForm } from '@/components/account/ProfileForm';
import { AddressBook } from '@/components/account/AddressBook';

export async function generateMetadata() {
  const t = await getTranslations('account');
  return { title: t('profile') };
}

export default async function ProfilePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations('account');

  return (
    <div className="space-y-12">
      <h1 className="text-2xl font-semibold">{t('profile')}</h1>
      <ProfileForm />
      <AddressBook />
    </div>
  );
}
