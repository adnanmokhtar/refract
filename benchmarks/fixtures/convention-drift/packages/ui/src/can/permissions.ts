import { useSyncExternalStore } from 'react';

let actions: string[] = [];
const listeners = new Set<() => void>();

export function setPermissions(next: string[]) {
  actions = next;
  listeners.forEach((l) => l());
}

export function usePermissions(): string[] {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => actions,
  );
}
