import { getTranslations } from 'next-intl/server';
import { SearchResults } from '@/components/search/SearchResults';

export async function generateMetadata() {
  const t = await getTranslations('search');
  return { title: t('title') };
}

export default async function SearchPage() {
  const t = await getTranslations('search');

  return (
    <section className="mt-8">
      <h1 className="text-2xl font-semibold">{t('title')}</h1>
      <SearchResults />
    </section>
  );
}
