import { createNavigationContainerRef } from '@react-navigation/native';

export const navigationRef = createNavigationContainerRef<Record<string, object | undefined>>();

export function navigate(name: string, params?: object): void {
  if (navigationRef.isReady()) navigationRef.navigate(name, params);
}
