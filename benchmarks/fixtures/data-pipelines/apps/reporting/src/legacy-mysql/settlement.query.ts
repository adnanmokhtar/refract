import type { Pool } from 'mysql2/promise';

/** Riyadh settlement day for the legacy shop database. */
export async function settlementDays(pool: Pool) {
  const [rows] = await pool.query(
    `SELECT DATE(CONVERT_TZ(paid_at, '+00:00', 'Asia/Riyadh')) AS settlement_day, SUM(amount_cents) AS total
       FROM payments GROUP BY settlement_day`,
  );
  return rows;
}
