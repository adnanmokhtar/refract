import { useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useModuleEnabled } from '../../shared/entitlements/use-module-enabled';
import { Button } from '../../components/Button';

interface GiftCard {
  id: string;
  code: string;
  balanceCents: number;
}

export function GiftCardsPage() {
  const enabled = useModuleEnabled('gift_cards');
  const [email, setEmail] = useState('');
  const cards = useQuery({ queryKey: ['gift-cards'], queryFn: () => http.get('gift-cards').json<GiftCard[]>(), enabled });
  const issue = useMutation({ mutationFn: () => http.post('gift-cards', { json: { amountCents: 2500, email } }).json<GiftCard>() });
  if (!enabled) return <p>Gift cards are part of the Growth and Scale plans.</p>;
  return (
    <section>
      <h1>Gift cards</h1>
      <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} aria-label="Recipient e-mail" />
      <Button onClick={() => issue.mutate()}>Issue a $25 card</Button>
      {issue.isError && <p role="alert">The card could not be issued.</p>}
      <ul>
        {(cards.data ?? []).map((c) => (
          <li key={c.id}>
            {c.code} · {(c.balanceCents / 100).toFixed(2)}
          </li>
        ))}
      </ul>
    </section>
  );
}
