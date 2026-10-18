import { useQuery } from '@tanstack/react-query';
import { apiClient } from '@acme/http';

export type AuditEntry = { id: string; at: string; actor: string; action: string };

export function useAuditLog() {
  return useQuery({ queryKey: ['audit'], queryFn: () => apiClient.get('audit').json<AuditEntry[]>() });
}
