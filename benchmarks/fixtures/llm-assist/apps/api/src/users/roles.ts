/** Workspace member roles. `system` is the synthetic actor that runs automations. */
export type MemberRole = 'owner' | 'admin' | 'agent' | 'viewer';

export const SYSTEM_ROLE = { role: 'system', label: 'System user' } as const;

export const ROLE_LABELS: Record<MemberRole, string> = {
  owner: 'Owner',
  admin: 'Administrator',
  agent: 'Agent',
  viewer: 'Read-only',
};

export function canEditMacros(role: MemberRole): boolean {
  return role === 'owner' || role === 'admin';
}
