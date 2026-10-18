import { useMe } from './useMe';

export function useCan(permission: string): boolean {
  const me = useMe();
  return Boolean(me?.permissions.includes(permission) || me?.roles.includes('admin'));
}
