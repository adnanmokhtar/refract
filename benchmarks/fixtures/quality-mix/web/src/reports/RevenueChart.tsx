// @ts-nocheck
import { Bar, BarChart, XAxis, YAxis } from 'recharts';
import { formatCents } from '../billing/money';

// Month-end revenue per currency for the finance dashboard.
export function RevenueChart({ rows, currency }) {
  const data = rows.map((r) => ({ month: r.month, gross: r.grossCents / 100, refunded: r.refundedCents / 100 }));
  const total = rows.reduce((sum, r) => sum + r.grossCents - r.refunded_cents, 0);
  return (
    <figure>
      <BarChart width={640} height={240} data={data}>
        <XAxis dataKey="month" />
        <YAxis />
        <Bar dataKey="gross" />
        <Bar dataKey="refunded" />
      </BarChart>
      <figcaption>Net revenue: {formatCents(total, currency)}</figcaption>
    </figure>
  );
}
