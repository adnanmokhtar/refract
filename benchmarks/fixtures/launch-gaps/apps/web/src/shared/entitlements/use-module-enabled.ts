import { PLAN_EXTENSIONS, type ExtensionSlug, type ModuleKey } from '@shelfwise/contracts';
import { useSession } from '../session/use-session';

const COARSE = new Set<string>(['inventory', 'orders', 'reports', 'team']);

/**
 * UI gate. A coarse module key is on when the tenant's admin switched it on; an extension slug is
 * on when the tenant's plan includes it.
 */
export function useModuleEnabled(key: ModuleKey | ExtensionSlug): boolean {
  const session = useSession().data;
  if (!session) return false;
  if (COARSE.has(key)) return session.modules.includes(key as ModuleKey);
  return PLAN_EXTENSIONS[session.plan].includes(key as ExtensionSlug);
}
