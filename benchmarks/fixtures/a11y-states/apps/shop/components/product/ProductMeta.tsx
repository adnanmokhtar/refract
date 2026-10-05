import { useTranslations } from 'next-intl';

export function ProductMeta({ sku, material }: { sku: string; material: string }) {
  const t = useTranslations('product');

  return (
    <dl className="mt-6 grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
      <dt className="text-gray-500">{t('details')}</dt>
      <dd>{material}</dd>
      <dt className="text-muted-foreground">SKU</dt>
      <dd className="font-mono">{sku}</dd>
    </dl>
  );
}
