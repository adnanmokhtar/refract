import { AppRegistry } from 'react-native';
import messaging from '@react-native-firebase/messaging';

import App from './App';
import { name as appName } from './app.json';

// Data-only pushes ("a pick list was reassigned") update the badge while the app is in the background.
messaging().setBackgroundMessageHandler(async (message) => {
  if (message.data?.kind === 'reassigned') {
    await messaging().setAutoInitEnabled(true);
  }
});

AppRegistry.registerComponent(appName, () => App);
