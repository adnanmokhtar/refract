import messaging from '@react-native-firebase/messaging';

import { api } from '../api/client';
import { navigate } from '../navigation/ref';

/** Registers the device for "new pick list" pushes and routes a tap to the list it names. */
export async function setUpPush(): Promise<void> {
  await messaging().requestPermission();
  const token = await messaging().getToken();
  await api.post('/staff/devices', { token });

  messaging().onTokenRefresh((next) => api.post('/staff/devices', { token: next }));

  messaging().onNotificationOpenedApp((message) => {
    const pickListId = message.data?.pickListId;
    if (typeof pickListId === 'string') navigate('PickList', { id: pickListId });
  });
}
