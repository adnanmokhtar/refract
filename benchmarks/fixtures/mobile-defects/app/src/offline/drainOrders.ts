import { db, type QueuedOrder } from './db';
import { sendQueued } from './orderQueue';

const MAX_ATTEMPTS = 5;

/**
 * Replays queued order writes, oldest first. Rows for one order depend on each other: an `amend` or a `cancel`
 * only makes sense after the `create` for the same order has reached the server.
 */
export async function drainOrders(): Promise<void> {
  const rows = await db.getAllAsync<QueuedOrder>(
    "SELECT * FROM order_queue WHERE status = 'pending' ORDER BY created_at",
  );
  for (const row of rows) {
    try {
      await sendQueued(row);
      await db.runAsync('DELETE FROM order_queue WHERE id = ?', row.id);
    } catch (error) {
      await db.runAsync('UPDATE order_queue SET attempts = attempts + 1 WHERE id = ?', row.id);
      if (row.attempts + 1 >= MAX_ATTEMPTS) {
        await db.runAsync("UPDATE order_queue SET status = 'failed' WHERE id = ?", row.id);
      }
      continue;
    }
  }
}
