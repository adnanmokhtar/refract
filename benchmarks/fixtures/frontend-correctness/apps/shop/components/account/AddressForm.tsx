'use client';

import { useMutation } from '@tanstack/react-query';
import { useTranslations } from 'next-intl';
import { useState } from 'react';
import { api, type Address } from '@/lib/api';

export function AddressForm({ address, onSaved }: { address?: Address; onSaved?: () => void }) {
  const t = useTranslations('account');
  const [line1, setLine1] = useState(address?.line1 ?? '');
  const [city, setCity] = useState(address?.city ?? '');
  const [phone, setPhone] = useState(address?.phone);

  const save = useMutation({
    mutationFn: (body: Omit<Address, 'id'>) =>
      address ? api.patch(`/me/addresses/${address.id}`, body) : api.post('/me/addresses', body),
    onSuccess: () => onSaved?.(),
  });

  return (
    <form
      className="space-y-4"
      onSubmit={(e) => {
        e.preventDefault();
        save.mutate({ line1, city, phone });
      }}
    >
      <label className="block text-sm font-medium">
        {t('line1')}
        <input value={line1} onChange={(e) => setLine1(e.target.value)} className="mt-1 h-11 w-full rounded-lg border px-3" />
      </label>
      <label className="block text-sm font-medium">
        {t('city')}
        <input value={city} onChange={(e) => setCity(e.target.value)} className="mt-1 h-11 w-full rounded-lg border px-3" />
      </label>
      <label className="block text-sm font-medium">
        {t('phone')}
        <input type="tel" value={address?.phone} onChange={(e) => setPhone(e.target.value)} className="mt-1 h-11 w-full rounded-lg border px-3" />
      </label>
      <button type="submit" disabled={save.isPending} className="h-11 rounded-lg bg-brand px-5 text-sm text-brand-foreground">
        {t('save')}
      </button>
    </form>
  );
}
