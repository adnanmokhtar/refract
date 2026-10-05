import { getTranslations, setRequestLocale } from 'next-intl/server';
import { WishlistGrid } from '@/components/account/WishlistGrid';
import { WishlistFilters } from '@/components/account/WishlistFilters';
import { SavedListsSortable } from '@/components/account/SavedListsSortable';

export async function generateMetadata() {
  const t = await getTranslations('account');
  return { title: t('wishlist') };
}

export default async function WishlistPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations('account');

  return (
    <div className="space-y-12">
      <h1 className="text-2xl font-semibold">{t('wishlist')}</h1>
      <WishlistFilters />
      <WishlistGrid />
      <SavedListsSortable />
    </div>
  );
}
