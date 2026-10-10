import { v4 as uuid } from 'uuid';

import { apiFetch } from '../api/http';
import { db, type QueuedOrder } from './db';

export type OrderOp = { kind: QueuedOrder['kind']; path: string; body: unknown };

/**
 * Queues an order write before the UI says "Order placed". The idempotency key is minted once, here, and stored
 * with the row, so every replay of this row sends the same key and the server applies it once.
 */
export async function enqueueOrder(op: OrderOp): Promise<string> {
  const id = uuid();
  const idempotencyKey = uuid();
  await db.runAsync(
    'INSERT INTO order_queue (id, kind, path, payload, idempotency_key, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    id,
    op.kind,
    op.path,
    JSON.stringify(op.body),
    idempotencyKey,
    Date.now(),
  );
  return id;
}

export function sendQueued(row: QueuedOrder) {
  return apiFetch(row.path, {
    method: 'POST',
    headers: { 'Idempotency-Key': row.idempotency_key },
    body: row.payload,
  });
}
