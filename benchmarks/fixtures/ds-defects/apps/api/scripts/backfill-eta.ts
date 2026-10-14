/**
 * One-off: recompute ETAs for shipments booked before the 2.12 model change. Run by hand:
 *   pnpm ts-node scripts/backfill-eta.ts --since=2026-08-01
 */
import { Pool } from 'pg';

async function main(): Promise<void> {
  const since = process.argv.find((a) => a.startsWith('--since='))?.slice(8) ?? '2026-08-01';
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const started = Date.now();
  const { rowCount } = await pool.query("UPDATE shipments SET eta = NULL WHERE created_at >= $1 AND status IN ('booked', 'in_transit')", [since]);
  console.log(`cleared ${rowCount} ETAs in ${Date.now() - started} ms; the eta-recompute schedule fills them within the hour`);
  await pool.end();
}

void main();
