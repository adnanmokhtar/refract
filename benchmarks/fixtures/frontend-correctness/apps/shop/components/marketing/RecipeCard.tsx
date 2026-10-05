import { useTranslations } from 'next-intl';

export function RecipeCard({ title, ingredientCount }: { title: string; ingredientCount: number }) {
  const t = useTranslations('recipes');

  return (
    <li className="rounded-xl border p-4">
      <h2 className="font-medium">{title}</h2>
      <p className="mt-1 text-sm text-stone-600">
        {ingredientCount} {ingredientCount === 1 ? t('item') : t('items')}
      </p>
    </li>
  );
}
