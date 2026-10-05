'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { Button } from '@/components/ui/Button';
import { AddressDialog } from './AddressDialog';

export function AddressBook() {
  const t = useTranslations('account');
  const [adding, setAdding] = useState(false);

  return (
    <section aria-labelledby="addresses-heading">
      <h2 id="addresses-heading" className="text-lg font-semibold">
        {t('addresses')}
      </h2>
      <Button variant="secondary" className="mt-4" onClick={() => setAdding(true)}>
        {t('addAddress')}
      </Button>
      {adding && <AddressDialog onClose={() => setAdding(false)} />}
    </section>
  );
}
