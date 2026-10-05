import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '../api/client';
import { RevenueChart } from './RevenueChart';
import { sortedPeriods } from './period-picker';

export function FinanceDashboard() {
  const { data: periods = [] } = useQuery({ queryKey: ['periods'], queryFn: () => api<string[]>('/reports/periods') });
  const [period, setPeriod] = useState<string | null>(null);
  const { data: rows = [] } = useQuery({
    queryKey: ['revenue', period],
    queryFn: () => api<{ month: string; grossCents: number; refundedCents: number }[]>(`/reports/revenue?month=${period}`),
    enabled: period !== null,
  });
  return (
    <section>
      <select aria-label="Period" onChange={(e) => setPeriod(e.target.value)}>
        {sortedPeriods(periods).map((p) => (
          <option key={p}>{p}</option>
        ))}
      </select>
      <RevenueChart rows={rows} currency="EUR" />
    </section>
  );
}
