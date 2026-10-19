import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { Button } from '../../components/Button';

interface Member {
  id: string;
  name: string;
  role: 'owner' | 'manager' | 'staff';
}

export function TeamPage() {
  const qc = useQueryClient();
  const { trackEvent } = useTracking();
  const [email, setEmail] = useState('');
  const [role, setRole] = useState<'staff' | 'manager'>('staff');
  const members = useQuery({ queryKey: ['team'], queryFn: () => http.get('team/members').json<Member[]>() });
  const invite = useMutation({ mutationFn: () => http.post('team/invites', { json: { email, role } }).json() });

  async function sendInvite() {
    await invite.mutateAsync();
    trackEvent('Invite Sent', { role, invitee_email: email });
    setEmail('');
    void qc.invalidateQueries({ queryKey: ['team'] });
  }

  return (
    <section>
      <h1>Team</h1>
      <ul>
        {(members.data ?? []).map((m) => (
          <li key={m.id}>
            {m.name} · {m.role}
          </li>
        ))}
      </ul>
      <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} aria-label="E-mail" />
      <select value={role} onChange={(e) => setRole(e.target.value as 'staff' | 'manager')}>
        <option value="staff">Staff</option>
        <option value="manager">Manager</option>
      </select>
      <Button onClick={() => void sendInvite()}>Invite</Button>
      {invite.isError && <p role="alert">The invite could not be sent (seat limit reached?).</p>}
    </section>
  );
}
