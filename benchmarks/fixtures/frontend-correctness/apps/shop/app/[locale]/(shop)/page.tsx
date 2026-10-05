import { setRequestLocale } from 'next-intl/server';
import { getCategory } from '@/lib/server/catalog';
import { Recommended } from '@/components/marketing/Recommended';
import { RecentSearches } from '@/components/search/RecentSearches';

export default async function HomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const featured = await getCategory(['featured']);

  return (
    <>
      <RecentSearches />
      <Recommended products={featured?.products ?? []} />
    </>
  );
}
