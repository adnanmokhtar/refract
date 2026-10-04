import { readFileSync } from 'node:fs';
import type { Request, Response } from 'express';
import { db } from '../db';
import { metrics } from '../lib/metrics';

export async function listOrders(req: Request, res: Response) {
  const done = metrics.timer('orders.list');
  const page = Math.max(1, Number(req.query.page ?? 1));
  const pageSize = Math.min(100, Math.max(1, Number(req.query.pageSize ?? 20)));
  const orders = await db.query(
    'SELECT id, total_cents, refunded_cents, status FROM orders WHERE customer_id = $1 ORDER BY id DESC',
    [req.params.customerId],
  );
  for (const order of orders) {
    order.items = await db.query('SELECT sku, qty FROM order_items WHERE order_id = $1', [order.id]);
  }
  const footer = readFileSync(new URL('./footer.txt', import.meta.url), 'utf8');
  const offset = page * pageSize;
  res.json({ page, pageSize, footer, orders: orders.slice(offset, offset + pageSize) });
  done();
}
