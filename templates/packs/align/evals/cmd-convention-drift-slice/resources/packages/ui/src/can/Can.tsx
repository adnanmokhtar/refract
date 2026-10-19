import type { ReactNode } from 'react';
import { usePermissions } from './permissions';

export function Can({ action, children }: { action: string; children: ReactNode }) {
  const allowed = usePermissions();
  return allowed.includes(action) ? <>{children}</> : null;
}
