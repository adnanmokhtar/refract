'use client';

import { useForm } from 'react-hook-form';
import { useTranslations } from 'next-intl';
import { api } from '@/lib/api';
import { Button } from '@/components/ui/Button';

type Address = { line1: string; city: string; postcode: string };

export function AddressDialog({ onClose }: { onClose: () => void }) {
  const t = useTranslations('account');
  const tc = useTranslations('common');
  const { register, handleSubmit, formState } = useForm<Address>();

  async function save(values: Address) {
    await api.post('/me/addresses', values);
    onClose();
  }

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/50 p-4">
      <div role="dialog" aria-modal="true" aria-labelledby="address-title" className="w-full max-w-md rounded-card bg-background p-6 shadow-xl">
        <h2 id="address-title" className="text-lg font-semibold">
          {t('addAddress')}
        </h2>
        <form className="mt-4 space-y-4" onSubmit={handleSubmit(save)}>
          <label className="block text-sm font-medium">
            {t('line1')}
            <input autoComplete="address-line1" className="mt-1 h-11 w-full rounded-lg border px-3" {...register('line1')} />
          </label>
          <label className="block text-sm font-medium">
            {t('city')}
            <input autoComplete="address-level2" className="mt-1 h-11 w-full rounded-lg border px-3" {...register('city')} />
          </label>
          <label className="block text-sm font-medium">
            {t('postcode')}
            <input autoComplete="postal-code" className="mt-1 h-11 w-full rounded-lg border px-3" {...register('postcode')} />
          </label>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={onClose}>
              {tc('cancel')}
            </Button>
            <Button type="submit" disabled={formState.isSubmitting} busy={formState.isSubmitting}>
              {tc('save')}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
