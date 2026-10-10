import { api } from '../api/client';
import { navigationRef } from '../navigation/ref';

type StaffSession = { accessToken: string; staffId: string; storeId: string };

let session: StaffSession | null = null;

export function currentToken(): string | null {
  return session?.accessToken ?? null;
}

export function setSession(next: StaffSession | null): void {
  session = next;
}

export async function signInWithInvite(inviteToken: string): Promise<void> {
  const { data } = await api.post<StaffSession>('/staff/session/invite', { inviteToken });
  setSession(data);
  navigationRef.resetRoot({ index: 0, routes: [{ name: 'Home' }] });
}
