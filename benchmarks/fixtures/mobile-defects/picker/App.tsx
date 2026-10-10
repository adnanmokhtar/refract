import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useEffect } from 'react';
import { Linking, PermissionsAndroid, Platform } from 'react-native';
import codePush from 'react-native-code-push';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { parseInvite } from './src/auth/magicLink';
import { signInWithInvite } from './src/auth/session';
import { navigationRef } from './src/navigation/ref';
import './src/offline/onStoreWifi';
import { setUpPush } from './src/push/notifications';
import { OrdersScreen } from './src/screens/OrdersScreen';
import { PickListScreen } from './src/screens/PickListScreen';
import { SignInScreen } from './src/screens/SignInScreen';
import { PickProvider } from './src/state/PickContext';

const Stack = createNativeStackNavigator();

function App() {
  useEffect(() => {
    if (Platform.OS === 'android') {
      PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT);
    }
    void setUpPush();

    const openInvite = (url: string | null) => {
      const token = url ? parseInvite(url) : null;
      if (token) void signInWithInvite(token);
    };
    Linking.getInitialURL().then(openInvite);
    const subscription = Linking.addEventListener('url', ({ url }) => openInvite(url));
    return () => subscription.remove();
  }, []);

  return (
    <SafeAreaProvider>
      <PickProvider>
        <NavigationContainer ref={navigationRef}>
          <Stack.Navigator initialRouteName="SignIn">
            <Stack.Screen name="SignIn" component={SignInScreen} options={{ headerShown: false }} />
            <Stack.Screen name="Home" component={OrdersScreen} options={{ title: "Today's orders" }} />
            <Stack.Screen name="PickList" component={PickListScreen} options={{ title: 'Pick list' }} />
          </Stack.Navigator>
        </NavigationContainer>
      </PickProvider>
    </SafeAreaProvider>
  );
}

export default codePush({ checkFrequency: codePush.CheckFrequency.ON_APP_RESUME })(App);
