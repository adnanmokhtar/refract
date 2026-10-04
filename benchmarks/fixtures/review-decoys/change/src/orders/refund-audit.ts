import type { Request, Response } from 'express';
import { db } from '../db';
import { logger } from '../lib/logger';
import { metrics } from '../lib/metrics';
import { audit } from '../lib/audit';

// POST /orders/:id/refund-adjustments — back-office correction of a refund total, in cents.
export async function adjustRefund(req: Request, res: Response) {
  const done = metrics.timer('orders.refund_adjust');
  const cents = Number.parseInt(String(req.body.cents), 10);
  if (!Number.isSafeInteger(cents) || cents <= 0) return res.status(422).json({ error: 'cents_must_be_positive_integer' });

  try {
    const rows = await db.query(
      'UPDATE orders SET refunded_cents = refunded_cents + $1 WHERE id = $2 AND refunded_cents + $1 <= total_cents RETURNING id, refunded_cents',
      [cents, req.params.id],
    );
    if (rows.length === 0) return res.status(409).json({ error: 'adjustment_exceeds_total' });

    void audit.record('refund.adjusted', { orderId: rows[0].id }).catch((err) => logger.warn('audit.failed', { err: String(err) }));
    logger.info('refund.adjusted', { orderId: rows[0].id, cents });
    return res.status(200).json(rows[0]);
  } catch (e) {
    logger.error('refund.adjust_failed', { orderId: req.params.id, err: String(e) });
    throw e;
  } finally {
    done();
  }
}
