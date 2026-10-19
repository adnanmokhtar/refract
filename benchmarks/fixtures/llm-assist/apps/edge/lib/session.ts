import { cookies } from 'next/headers';

export interface EdgeSession {
  userId: string;
  tenantId: string;
}

export async function requireSession(): Promise<EdgeSession> {
  const jar = await cookies();
  const raw = jar.get('qd_session')?.value;
  if (!raw) throw new Response('Unauthorized', { status: 401 });
  const res = await fetch(`${process.env.API_INTERNAL_URL}/auth/session`, { headers: { cookie: `qd_session=${raw}` } });
  if (!res.ok) throw new Response('Unauthorized', { status: 401 });
  return res.json();
}
