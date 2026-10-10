import { QueryClientProvider } from '@tanstack/react-query';
import * as Notifications from 'expo-notifications';
import { Stack, router } from 'expo-router';
import { useEffect } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { queryClient } from '../src/api/queryClient';
import { wipeKeychainOnFreshInstall } from '../src/auth/freshInstall';
import '../src/offline/onReconnect';
import { BasketProvider } from '../src/state/BasketProvider';

export default function RootLayout() {
  const lastResponse = Notifications.useLastNotificationResponse();

  useEffect(() => {
    void wipeKeychainOnFreshInstall();
  }, []);

  useEffect(() => {
    const orderId = lastResponse?.notification.request.content.data?.orderId;
    if (typeof orderId === 'string') router.push(`/orders/${orderId}`);
  }, [lastResponse]);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <QueryClientProvider client={queryClient}>
          <BasketProvider>
            <Stack screenOptions={{ headerShown: false }} />
          </BasketProvider>
        </QueryClientProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
