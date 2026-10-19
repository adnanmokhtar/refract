import { useEffect, useState } from 'react';
import { http } from '../../shared/api/http';

type Invite = { id: string; email: string; role: string };

export function TeamPage() {
  const [invites, setInvites] = useState<Invite[]>([]);
  useEffect(() => {
    http.get('team/invites').json<Invite[]>().then(setInvites);
  }, []);
  const invite = (email: string) => http.post('team/invites', { json: { email, role: 'staff' } });
  return (
    <section>
      <h1>Team</h1>
      <button onClick={() => invite(prompt('E-mail') ?? '')}>Invite</button>
      <ul>
        {invites.map((i) => (
          <li key={i.id}>{i.email} — pending</li>
        ))}
      </ul>
    </section>
  );
}
