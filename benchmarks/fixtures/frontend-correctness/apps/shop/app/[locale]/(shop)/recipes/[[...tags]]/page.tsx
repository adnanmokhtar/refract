import { notFound } from 'next/navigation';
import { getTranslations } from 'next-intl/server';
import { RecipeCard } from '@/components/marketing/RecipeCard';

const TAGS = ['quick', 'vegetarian', 'family', 'baking'] as const;
type Recipe = { id: string; title: string; ingredientCount: number };

async function getRecipes(tag?: string): Promise<Recipe[]> {
  const res = await fetch(`${process.env.CONTENT_API_URL}/recipes${tag ? `?tag=${tag}` : ''}`, { next: { revalidate: 3600 } });
  return res.ok ? res.json() : [];
}

export default async function RecipesPage({ params }: { params: Promise<{ tags?: string[] }> }) {
  const { tags = [] } = await params;
  const tag = tags[0];
  if (tags.length > 1 || (tag && !TAGS.includes(tag as (typeof TAGS)[number]))) notFound();
  const t = await getTranslations('recipes');
  const recipes = await getRecipes(tag);

  return (
    <section className="mt-8">
      <h1 className="text-2xl font-semibold">{t('title')}</h1>
      <ul className="mt-6 grid gap-4 sm:grid-cols-3">
        {recipes.map((r) => (
          <RecipeCard key={r.id} title={r.title} ingredientCount={r.ingredientCount} />
        ))}
      </ul>
    </section>
  );
}
