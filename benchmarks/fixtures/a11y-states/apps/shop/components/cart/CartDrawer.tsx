'use client';

import * as Dialog from '@radix-ui/react-dialog';
import Link from 'next/link';
import { useTranslations } from 'next-intl';
import { CartLine } from './CartLine';
import { CartSync } from './CartSync';
import type { CartLine as Line } from '@/lib/api';

export function CartDrawer({
  open,
  onOpenChange,
  lines,
  onRemove,
  onIncrease,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  lines: Line[];
  onRemove: (id: string) => void;
  onIncrease: (id: string) => void;
}) {
  const t = useTranslations('cart');
  const tc = useTranslations('common');

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-40 bg-black/40 transition-opacity duration-150 data-[state=closed]:opacity-0" />
        <Dialog.Content className="fixed inset-y-0 end-0 z-50 flex w-full max-w-sm flex-col bg-background p-6 shadow-xl">
          <div className="flex items-center justify-between">
            <Dialog.Title className="text-lg font-semibold">{t('title')}</Dialog.Title>
            <Dialog.Close asChild>
              <button
                type="button"
                aria-label={tc('close')}
                className="grid size-11 place-items-center rounded-full text-xl hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring"
              >
                ×
              </button>
            </Dialog.Close>
          </div>
          <ul className="mt-4 flex-1 divide-y overflow-y-auto">
            {lines.map((line) => (
              <CartLine key={line.id} line={line} onRemove={onRemove} onIncrease={onIncrease} />
            ))}
          </ul>
          <Link href="/checkout" className="mt-4 grid h-11 place-items-center rounded-lg bg-primary text-primary-foreground">
            {t('checkout')}
          </Link>
          <CartSync lines={lines} />
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
