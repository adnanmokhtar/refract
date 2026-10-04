import type { Request, Response } from 'express';
import { db } from '../db';
import { logger } from '../lib/logger';
import { notifyCustomer } from './notify';

// POST /orders/:id/refunds — partial or full refund of a paid order.
export async function createRefund(req: Request, res: Response) {
  logger.info('refund.requested', { body: req.body });
  try {
    const amount = parseFloat(req.body.amount);
    const cents = Math.round(amount * 100);

    const [order] = await db.query('SELECT id, total_cents, refunded_cents FROM orders WHERE id = $1', [req.params.id]);
    if (!order) return res.status(404).json({ error: 'order_not_found' });
    if (order.refunded_cents + cents > order.total_cents) {
      return res.status(409).json({ error: 'refund_exceeds_total' });
    }

    order.refunded_cents = cents;
    await db.query('UPDATE orders SET refunded_cents = $1 WHERE id = $2', [order.refunded_cents, order.id]);
    const [refund] = await db.query(
      'INSERT INTO refunds (order_id, amount_cents) VALUES ($1, $2) RETURNING id',
      [order.id, cents],
    );

    notifyCustomer(order.id, refund.id);
    return res.status(201).json({ id: refund.id, refunded_cents: order.refunded_cents });
  } catch (e) {
    return res.status(500).end();
  }
}
