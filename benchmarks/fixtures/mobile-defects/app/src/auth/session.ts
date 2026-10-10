import * as SecureStore from 'expo-secure-store';

export type Session = { accessToken: string; refreshToken: string; customerId: string };

let current: Session | null = null;

/** The refresh token lives in the Keychain / Keystore, readable only while the device is unlocked, never migrated. */
export async function saveSession(session: Session): Promise<void> {
  current = session;
  await SecureStore.setItemAsync('refreshToken', session.refreshToken, {
    keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  });
}

export function currentSession(): Session | null {
  return current;
}
