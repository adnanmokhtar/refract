import { useEffect, useState } from 'react';
import { api } from '../api/client';

export interface CurrentUser {
  id: string;
  name: string;
}

// Degrade mode, by design (docs/portal/session.md): if /me fails, the portal renders as signed out
// and the sign-in button re-runs the session; the failure is logged and counted.
export function useCurrentUser() {
  const [user, setUser] = useState<CurrentUser | null>(null);

  useEffect(() => {
    let cancelled = false;
    api<CurrentUser>('/me')
      .then((me) => {
        if (!cancelled) setUser(me);
      })
      .catch((e: unknown) => {
        console.warn('session.me_failed', e);
        window.dispatchEvent(new CustomEvent('metric', { detail: { name: 'session.me_failed' } }));
        if (!cancelled) setUser(null);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return user;
}
