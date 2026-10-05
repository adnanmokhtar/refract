'use client';

import { Bar, BarChart, CartesianGrid, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { useLocale, useTranslations } from 'next-intl';
import { useSpend } from '@/lib/queries';
import { formatPrice } from '@/lib/format';
import { ErrorState } from '@/components/ui/ErrorState';

// Month-over-month spend, coloured by whether the customer spent more or less than the month before.
export function SpendChart() {
  const t = useTranslations('account');
  const locale = useLocale();
  const { data, isPending, isError, refetch } = useSpend();

  if (isPending) return <div aria-busy="true" className="h-72 animate-pulse rounded-card bg-muted" />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;
  if (data.length === 0) return <p className="text-sm text-muted-foreground">—</p>;

  return (
    <figure>
      <figcaption className="mb-3 text-sm font-medium">{t('monthlySpend')}</figcaption>
      <ResponsiveContainer width="100%" height={288}>
        <BarChart data={data}>
          <CartesianGrid vertical={false} strokeDasharray="3 3" />
          <XAxis dataKey="month" />
          <YAxis domain={[40, 'auto']} tickFormatter={(v: number) => formatPrice(v, locale)} />
          <Tooltip formatter={(v: number) => formatPrice(v, locale)} />
          <Bar dataKey="spend">
            {data.map((point) => (
              <Cell key={point.month} fill={point.change >= 0 ? '#16a34a' : '#dc2626'} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </figure>
  );
}
