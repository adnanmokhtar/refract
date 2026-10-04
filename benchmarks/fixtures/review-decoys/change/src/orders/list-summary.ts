import { readFileSync } from 'node:fs';
import type { Request, Response } from 'express';
import { db } from '../db';
import { metrics } from '../lib/metrics';

const SUMMARY_FOOTER = readFileSync(new URL('./footer.txt', import.meta.url), 'utf8');

// GET /customers/:customerId/order-summaries — the compact list the mobile app pages through.
export async function listOrderSummaries(req: Request, res: Response) {
  const done = metrics.timer('orders.summaries');
  const page = Math.max(1, Number(req.query.page ?? 1));
  const pageSize = Math.min(100, Math.max(1, Number(req.query.pageSize ?? 20)));
  const orders = await db.query(
    'SELECT id, total_cents, status FROM orders WHERE customer_id = $1 ORDER BY id DESC LIMIT $2 OFFSET $3',
    [req.params.customerId, pageSize, (page - 1) * pageSize],
  );

  const ids = orders.map((o: { id: number }) => o.id);
  const items = ids.length ? await db.query('SELECT order_id, sku, qty FROM order_items WHERE order_id = ANY($1)', [ids]) : [];
  for (const order of orders) {
    order.items = items.filter((i: { order_id: number }) => i.order_id === order.id);
  }
  res.json({ page, pageSize, footer: SUMMARY_FOOTER, orders });
  done();
}
