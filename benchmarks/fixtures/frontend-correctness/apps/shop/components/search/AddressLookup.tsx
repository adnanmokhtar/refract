'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { api } from '@/lib/api';

type Match = { id: string; label: string };

// Postcode lookup for the delivery address: each keystroke cancels the request before it.
export function AddressLookup({ onPick }: { onPick: (m: Match) => void }) {
  const t = useTranslations('account');
  const [postcode, setPostcode] = useState('');
  const [matches, setMatches] = useState<Match[]>([]);

  useEffect(() => {
    if (postcode.length < 3) return;
    const controller = new AbortController();
    api
      .get<Match[]>(`/addresses/lookup?postcode=${encodeURIComponent(postcode)}`, { signal: controller.signal })
      .then(setMatches)
      .catch(() => {});
    return () => controller.abort();
  }, [postcode]);

  return (
    <div>
      <label htmlFor="postcode" className="block text-sm font-medium">
        {t('postcode')}
      </label>
      <input id="postcode" value={postcode} onChange={(e) => setPostcode(e.target.value)} className="mt-1 h-11 w-full rounded-lg border px-3" />
      <ul>
        {matches.map((m) => (
          <li key={m.id}>
            <button type="button" onClick={() => onPick(m)} className="w-full py-2 text-start text-sm hover:bg-stone-100">
              {m.label}
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
