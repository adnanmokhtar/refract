'use client';

import { useQuery } from '@tanstack/react-query';
import { useLocale, useTranslations } from 'next-intl';

type Slot = { id: string; start: string; end: string; full: boolean };

const SLOTS_API = 'https://slots.harbor.example/v1/slots';

export function DeliverySlots({ postcode, onPick }: { postcode: string; onPick: (slot: Slot) => void }) {
  const t = useTranslations('checkout');
  const locale = useLocale();
  const { data, isPending, isError } = useQuery({
    queryKey: ['slots', postcode],
    queryFn: async () => {
      const res = await fetch(`${SLOTS_API}?postcode=${postcode}`, {
        headers: { authorization: `Bearer ${process.env.SLOTS_API_TOKEN}` },
      });
      return (await res.json()) as Slot[];
    },
  });

  if (isPending) return <p aria-busy="true">{t('loadingSlots')}</p>;
  if (isError) return <p role="alert">{t('slotsError')}</p>;

  const fmt = new Intl.DateTimeFormat(locale, { weekday: 'short', hour: 'numeric', minute: '2-digit' });
  return (
    <ul className="grid grid-cols-2 gap-2">
      {data.map((slot) => (
        <li key={slot.id}>
          <button type="button" disabled={slot.full} onClick={() => onPick(slot)} className="w-full rounded-lg border p-3 text-sm">
            {fmt.formatRange(new Date(slot.start), new Date(slot.end))}
          </button>
        </li>
      ))}
    </ul>
  );
}
