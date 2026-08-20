import type { ReactNode } from 'react';
import { usePermissions } from '../../hooks/usePermissions';

// Renders children only when the current user holds `action`. Every gated affordance in
// the app goes through this component so the permission source stays single.
export function Can({ action, children }: { action: string; children: ReactNode }) {
  const { allowed } = usePermissions();
  if (!allowed.includes(action)) return null;
  return <>{children}</>;
}
