import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { http } from '../../shared/api/http';
import { EmptyHint } from '../../components/EmptyHint';
import { useTopProducts } from './use-top-products';
import { PlanBadge } from '../billing/PlanBadge';

interface WeeklyInsight {
  metric: string;
  change: number;
  label: string;
}

export function DashboardPage() {
  const { t } = useTranslation();
  const top = useTopProducts();
  const insights = useQuery({ queryKey: ['insights', 'weekly'], queryFn: () => http.get('insights/weekly').json<WeeklyInsight[]>() });
  return (
    <section>
      <header>
        <h1>{t('dashboard.title')}</h1>
        <PlanBadge />
      </header>
      <div className="grid">
        <article>
          <h2>{t('dashboard.insights')}</h2>
          <ul>
            {(insights.data ?? []).map((i) => (
              <li key={i.metric}>{i.label}</li>
            ))}
          </ul>
        </article>
        <article>
          <h2>{t('dashboard.topProducts')}</h2>
          <ol>
            {top.map((p) => (
              <li key={p.sku}>
                {p.name} · {p.unitsSold} sold
              </li>
            ))}
          </ol>
          <a href="#">{t('dashboard.viewAll')}</a>
        </article>
        <EmptyHint title={t('dashboard.forecast')} />
      </div>
    </section>
  );
}
