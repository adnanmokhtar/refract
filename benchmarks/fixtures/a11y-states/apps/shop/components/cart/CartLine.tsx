'use client';

import Image from 'next/image';
import { Plus, X } from 'lucide-react';
import { useLocale, useTranslations } from 'next-intl';
import { formatPrice } from '@/lib/format';
import type { CartLine as Line } from '@/lib/api';

export function CartLine({
  line,
  onRemove,
  onIncrease,
}: {
  line: Line;
  onRemove: (id: string) => void;
  onIncrease: (id: string) => void;
}) {
  const t = useTranslations('cart');
  const locale = useLocale();

  return (
    <li className="flex gap-3 py-4">
      <Image src={line.image} alt="" width={64} height={80} className="rounded-md" />
      <div className="flex-1">
        <p className="text-sm font-medium">{line.name}</p>
        <p className="text-sm text-muted-foreground">{formatPrice(line.price * line.qty, locale)}</p>
        <div className="mt-2 flex items-center gap-1">
          <button
            type="button"
            aria-label={t('remove', { name: line.name })}
            onClick={() => onRemove(line.id)}
            className="grid size-4 place-items-center rounded text-muted-foreground hover:text-foreground"
          >
            <X aria-hidden className="size-3" />
          </button>
          <span className="w-6 text-center text-sm tabular-nums">{line.qty}</span>
          <button
            type="button"
            aria-label={t('increase', { name: line.name })}
            onClick={() => onIncrease(line.id)}
            className="grid size-4 place-items-center rounded text-muted-foreground hover:text-foreground"
          >
            <Plus aria-hidden className="size-3" />
          </button>
        </div>
      </div>
    </li>
  );
}
