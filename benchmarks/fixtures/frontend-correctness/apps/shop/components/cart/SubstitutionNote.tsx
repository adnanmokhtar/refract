import { Info } from 'lucide-react';
import { useTranslations } from 'next-intl';

export function SubstitutionNote() {
  const t = useTranslations('cart');

  return (
    <p className="flex items-start text-xs text-stone-500">
      <Info aria-hidden className="mt-0.5 size-4 shrink-0" />
      <span className="ms-4">{t('substitutions')}</span>
    </p>
  );
}
