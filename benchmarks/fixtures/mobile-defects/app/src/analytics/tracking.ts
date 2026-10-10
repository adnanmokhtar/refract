import appsFlyer from 'react-native-appsflyer';
import { requestTrackingPermissionsAsync } from 'expo-tracking-transparency';

/** Install attribution for paid campaigns. Called once from onboarding, after the welcome screen. */
export async function startAttribution(): Promise<void> {
  const { granted } = await requestTrackingPermissionsAsync();
  appsFlyer.initSdk({
    devKey: process.env.EXPO_PUBLIC_APPSFLYER_DEV_KEY ?? '',
    appId: '1580000000',
    isDebug: false,
    onInstallConversionDataListener: false,
    timeToWaitForATTUserAuthorization: granted ? 0 : 10,
  });
}
