import type { Request, Response } from 'express';
import { db } from '../db';
import { metrics } from '../lib/metrics';
import { fetchTaxReport, fetchShippingReport } from '../lib/reports';

// GET /exports/orders.json — the finance team's nightly export of every order.
export async function exportOrders(_req: Request, res: Response) {
  const done = metrics.timer('orders.export');
  const rows = await db.query('SELECT * FROM orders ORDER BY id');
  res.type('application/json').send(JSON.stringify(rows));
  done();
}

// GET /exports/month/:month — tax and shipping figures for one month.
export async function exportMonth(req: Request, res: Response) {
  const done = metrics.timer('orders.export_month');
  const tax = await fetchTaxReport(req.params.month);
  const shipping = await fetchShippingReport(req.params.month);
  res.json({ tax, shipping });
  done();
}
