import messaging from '@react-native-firebase/messaging';

import { api } from '../api/client';
import { navigationRef } from '../navigation/ref';
import { clear as clearOutbox } from '../offline/outbox';
import { setSession } from './session';

export async function logout(): Promise<void> {
  await api.delete('/staff/devices/current');
  await messaging().deleteToken();
  clearOutbox();
  setSession(null);
  navigationRef.resetRoot({ index: 0, routes: [{ name: 'SignIn' }] });
}
