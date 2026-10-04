import { createContext, ReactNode, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';

export interface SessionUser {
  id: string;
  email: string;
  displayName: string;
  stores: { id: string; slug: string; role: 'owner' | 'manager' | 'staff' }[];
}

interface SessionContextValue {
  user: SessionUser | null;
  loading: boolean;
  signOut: () => Promise<void>;
}

const SessionContext = createContext<SessionContextValue>({ user: null, loading: true, signOut: async () => undefined });

export function SessionProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<SessionUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api<SessionUser>('/api/me')
      .then(setUser)
      .catch(() => setUser(null))
      .finally(() => setLoading(false));
  }, []);

  const signOut = useCallback(async () => {
    await api('/api/auth/logout', { method: 'POST' });
    setUser(null);
  }, []);

  const value = useMemo(() => ({ user, loading, signOut }), [user, loading, signOut]);

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export const useSession = () => useContext(SessionContext);
