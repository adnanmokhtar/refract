'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { DeliverySlots } from './DeliverySlots';

export function CheckoutSlots() {
  const t = useTranslations('checkout');
  const [picked, setPicked] = useState<string | null>(null);

  return (
    <section>
      <h2 className="text-sm font-medium">{t('slot')}</h2>
      <DeliverySlots postcode="HB1" onPick={(slot) => setPicked(slot.id)} />
      {picked && <input type="hidden" name="slot" form="checkout" value={picked} />}
    </section>
  );
}
