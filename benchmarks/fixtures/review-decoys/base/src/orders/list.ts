import type { Request, Response } from 'express';
import { db } from '../db';
import { metrics } from '../lib/metrics';

export async function listOrders(req: Request, res: Response) {
  const done = metrics.timer('orders.list');
  const page = Math.max(1, Number(req.query.page ?? 1));
  const pageSize = Math.min(100, Math.max(1, Number(req.query.pageSize ?? 20)));
  const orders = await db.query(
    'SELECT id, total_cents, status FROM orders WHERE customer_id = $1 ORDER BY id DESC LIMIT $2 OFFSET $3',
    [req.params.customerId, pageSize, (page - 1) * pageSize],
  );
  res.json({ page, pageSize, orders });
  done();
}
