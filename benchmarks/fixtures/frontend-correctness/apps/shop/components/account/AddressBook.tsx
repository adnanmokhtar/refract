'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { AddressForm } from './AddressForm';
import { AddressLookup } from '../search/AddressLookup';

export function AddressBook() {
  const t = useTranslations('account');
  const [line1, setLine1] = useState('');

  return (
    <section className="space-y-4">
      <h2 className="text-lg font-semibold">{t('addAddress')}</h2>
      <AddressLookup onPick={(m) => setLine1(m.label)} />
      <AddressForm key={line1} address={line1 ? { id: '', line1, city: '' } : undefined} />
    </section>
  );
}
