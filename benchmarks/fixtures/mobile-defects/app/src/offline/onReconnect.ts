import NetInfo from '@react-native-community/netinfo';

import { drainOrders } from './drainOrders';

// Module scope: one subscription for the life of the app, installed by the root layout's import.
NetInfo.addEventListener((state) => {
  if (state.isInternetReachable) void drainOrders();
});
