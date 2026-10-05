'use client';

import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { useTranslations } from 'next-intl';
import { usePointsTrend } from '@/lib/queries';
import { ErrorState } from '@/components/ui/ErrorState';

// Weekly points balance. Weeks the ledger job did not run come back as null.
export function PointsTrend() {
  const t = useTranslations('account');
  const { data, isPending, isError, refetch } = usePointsTrend();

  if (isPending) return <div aria-busy="true" className="h-72 animate-pulse rounded-card bg-muted" />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;
  if (data.length === 0) return <p className="text-sm text-muted-foreground">—</p>;

  return (
    <figure>
      <figcaption className="mb-3 text-sm font-medium">{t('pointsTrend')}</figcaption>
      <ResponsiveContainer width="100%" height={288}>
        <LineChart data={data}>
          <CartesianGrid vertical={false} strokeDasharray="3 3" />
          <XAxis dataKey="week" />
          <YAxis allowDecimals={false} label={{ value: t('loyalty'), angle: -90, position: 'insideLeft' }} />
          <Tooltip />
          <Line type="monotone" dataKey="points" stroke="var(--color-primary)" strokeWidth={2} dot={false} connectNulls />
        </LineChart>
      </ResponsiveContainer>
    </figure>
  );
}
