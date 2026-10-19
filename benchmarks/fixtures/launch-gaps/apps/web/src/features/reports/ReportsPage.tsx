import { useMutation, useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { http } from '../../shared/api/http';
import { Button } from '../../components/Button';

interface Overview {
  revenueCents: number;
  orders: number;
  averageOrderCents: number;
}

interface CohortRow {
  month: string;
  retained: number[];
}

export function ReportsPage() {
  const { t } = useTranslation();
  const overview = useQuery({ queryKey: ['reports', 'overview'], queryFn: () => http.get('reports').json<Overview>() });
  const cohorts = useQuery({ queryKey: ['reports', 'cohorts'], queryFn: () => http.get('reports/cohorts').json<CohortRow[]>() });
  const exportCsv = useMutation({ mutationFn: () => http.post('exports', { json: { report: 'overview', format: 'csv' } }).blob() });
  const schedule = useMutation({
    mutationFn: () => http.post('reports/schedules', { json: { cadence: 'weekly', recipients: [] } }).json(),
  });

  return (
    <section>
      <h1>{t('reports.title')}</h1>
      <div className="actions">
        <Button variant="secondary" onClick={() => exportCsv.mutate()}>
          {t('reports.export')}
        </Button>
        <Button variant="secondary" onClick={() => schedule.mutate()}>
          {t('reports.schedule')}
        </Button>
      </div>
      {overview.data && (
        <dl>
          <dt>Revenue</dt>
          <dd>{(overview.data.revenueCents / 100).toFixed(2)}</dd>
          <dt>Orders</dt>
          <dd>{overview.data.orders}</dd>
        </dl>
      )}
      <table aria-label="Cohort retention">
        <tbody>
          {(cohorts.data ?? []).map((c) => (
            <tr key={c.month}>
              <th>{c.month}</th>
              {c.retained.map((r, i) => (
                <td key={i}>{Math.round(r * 100)}%</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
