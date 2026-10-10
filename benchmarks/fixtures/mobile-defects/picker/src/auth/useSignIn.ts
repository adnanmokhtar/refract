import type { NavigationProp } from '@react-navigation/native';

import { api } from '../api/client';
import { setSession } from './session';

type StaffSession = { accessToken: string; staffId: string; storeId: string };

export function useSignIn(navigation: NavigationProp<Record<string, object | undefined>>) {
  return async function signIn(badgeId: string, pin: string): Promise<void> {
    const { data } = await api.post<StaffSession>('/staff/session', { badgeId, pin });
    setSession(data);
    navigation.navigate('Home');
  };
}
