import { useQuery } from '@tanstack/react-query';
import { apiClient } from '@acme/http';

type ReportRow = { id: string; label: string; value: string };

export function useReports() {
  return useQuery({ queryKey: ['reports'], queryFn: () => apiClient.get('reports/summary').json<ReportRow[]>() });
}
