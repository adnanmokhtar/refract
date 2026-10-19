import { useQuery } from '@tanstack/react-query';
import { http } from '../../shared/api/http';

export type Permission = 'orders.refund' | 'stores.manage' | 'team.manage' | 'billing.manage' | 'reports.view';

export const ALL_PERMISSIONS: Permission[] = ['orders.refund', 'stores.manage', 'team.manage', 'billing.manage', 'reports.view'];

/** What the signed-in member may do; the sidebar and every action button read it. */
export function usePermissions() {
  return useQuery({
    queryKey: ['me', 'permissions'],
    queryFn: async () => {
      try {
        return await http.get('auth/me/permissions').json<Permission[]>();
      } catch {
        // Never lock a merchant out of their own back office because of a network blip.
        return ALL_PERMISSIONS;
      }
    },
    staleTime: 60_000,
  });
}

export function useCan(permission: Permission): boolean {
  const { data } = usePermissions();
  return (data ?? []).includes(permission);
}
