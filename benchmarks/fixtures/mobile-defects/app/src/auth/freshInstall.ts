import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';

const HAS_LAUNCHED = 'has_launched';

/** Keychain items survive an uninstall on iOS; AsyncStorage does not. A missing marker means a fresh install. */
export async function wipeKeychainOnFreshInstall(): Promise<void> {
  if (await AsyncStorage.getItem(HAS_LAUNCHED)) return;
  await SecureStore.deleteItemAsync('refreshToken');
  await AsyncStorage.setItem(HAS_LAUNCHED, '1');
}
