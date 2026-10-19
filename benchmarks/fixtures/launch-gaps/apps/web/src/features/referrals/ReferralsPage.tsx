import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { Button } from '../../components/Button';

interface Referral {
  id: string;
  email: string;
  status: 'sent' | 'signed_up' | 'activated';
}

/** Invite another shop; both get a month free when it activates. */
export function ReferralsPage() {
  const qc = useQueryClient();
  const [email, setEmail] = useState('');
  const mine = useQuery({ queryKey: ['referrals'], queryFn: () => http.get('referrals').json<Referral[]>() });
  const send = useMutation({
    mutationFn: () => http.post('referrals', { json: { email } }).json<Referral>(),
    onSuccess: () => {
      setEmail('');
      void qc.invalidateQueries({ queryKey: ['referrals'] });
    },
  });
  return (
    <section>
      <h1>Refer a shop</h1>
      <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} aria-label="Their e-mail" />
      <Button onClick={() => send.mutate()} disabled={send.isPending || !email}>
        Send invite
      </Button>
      <ul>
        {(mine.data ?? []).map((r) => (
          <li key={r.id}>
            {r.email} · {r.status}
          </li>
        ))}
      </ul>
    </section>
  );
}
