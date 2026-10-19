'use client';

import { useEffect, useRef } from 'react';
import { useTranslations } from 'next-intl';
import { Button } from '@/components/ui/Button';

export function ConfirmDeleteDialog({
  open,
  title,
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const t = useTranslations('common');
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);

  return (
    <dialog ref={ref} onClose={onCancel} aria-labelledby="confirm-title" className="rounded-card p-6 backdrop:bg-black/50">
      <h2 id="confirm-title" className="text-lg font-semibold">
        {title}
      </h2>
      <div className="mt-6 flex justify-end gap-2">
        <Button variant="ghost" onClick={onCancel} autoFocus>
          {t('cancel')}
        </Button>
        <Button onClick={onConfirm}>{t('delete')}</Button>
      </div>
    </dialog>
  );
}
