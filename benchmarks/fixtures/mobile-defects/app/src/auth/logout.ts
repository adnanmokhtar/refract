import CookieManager from '@react-native-cookies/cookies';
import * as SecureStore from 'expo-secure-store';

import { queryClient } from '../api/queryClient';
import { db } from '../offline/db';
import { removePushToken } from '../push/registerPush';

export async function logout(): Promise<void> {
  await removePushToken();
  await db.runAsync('DELETE FROM order_queue');
  queryClient.clear();
  await CookieManager.clearAll(true);
  await SecureStore.deleteItemAsync('refreshToken');
}
