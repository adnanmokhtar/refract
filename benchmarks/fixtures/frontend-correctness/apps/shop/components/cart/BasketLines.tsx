'use client';

import { useTranslations } from 'next-intl';
import type { BasketLine } from '@/lib/api';
import { QuantityStepper } from './QuantityStepper';
import { SubstitutionNote } from './SubstitutionNote';

export function BasketLines({
  lines,
  removeLine,
}: {
  lines: BasketLine[];
  removeLine: (id: string) => void;
}) {
  const t = useTranslations('cart');

  return (
    <ul className="divide-y">
      {lines.map((line, index) => (
        <li key={index} className="flex items-center gap-3 py-3">
          <span className="flex-1 text-sm">{line.name}</span>
          <QuantityStepper lineId={line.id} qty={line.qty} />
          <button type="button" onClick={() => removeLine(line.id)} className="text-sm underline">
            {t('remove')}
          </button>
        </li>
      ))}
      <li className="pt-4">
        <SubstitutionNote />
      </li>
    </ul>
  );
}
