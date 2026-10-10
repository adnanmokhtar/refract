import NetInfo from '@react-native-community/netinfo';

import { flush } from './outbox';

// Module scope: one subscription for the life of the app. Reachability, not link state: store Wi-Fi has a portal.
NetInfo.addEventListener((state) => {
  if (state.isInternetReachable) void flush();
});
