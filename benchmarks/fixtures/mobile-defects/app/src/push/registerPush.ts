import * as Notifications from 'expo-notifications';
import { Linking, Platform } from 'react-native';

import { apiFetch } from '../api/http';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: false,
    shouldSetBadge: false,
  }),
});

Notifications.addPushTokenListener(({ data }) => {
  void apiFetch('/me/devices', { method: 'POST', body: JSON.stringify({ pushToken: data }) });
});

export async function registerForPush(onBlocked: (openSettings: () => void) => void): Promise<void> {
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('orders', {
      name: 'Order updates',
      importance: Notifications.AndroidImportance.HIGH,
    });
  }
  const current = await Notifications.getPermissionsAsync();
  let status = current.status;
  if (status !== 'granted' && current.canAskAgain) {
    status = (await Notifications.requestPermissionsAsync()).status;
  }
  if (status !== 'granted') {
    if (!current.canAskAgain) onBlocked(() => void Linking.openSettings());
    return;
  }
  const { data } = await Notifications.getDevicePushTokenAsync();
  await apiFetch('/me/devices', { method: 'POST', body: JSON.stringify({ pushToken: data }) });
}

export async function removePushToken(): Promise<void> {
  await apiFetch('/me/devices/current', { method: 'DELETE' });
}
