import { useQuery } from '@tanstack/react-query';
import type { ModuleKey, PlanKey } from '@shelfwise/contracts';
import { http } from '../api/http';

export interface Session {
  id: string;
  email: string;
  tenantId: string;
  plan: PlanKey;
  modules: ModuleKey[];
  roles: string[];
}

export function useSession() {
  return useQuery({ queryKey: ['session'], queryFn: () => http.get('auth/me').json<Session>(), retry: false });
}
