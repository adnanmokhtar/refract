import type { Pool } from 'mysql2/promise';

/** Berlin order days for the legacy shop database. */
export async function berlinOrderDays(pool: Pool) {
  const [rows] = await pool.query(
    `SELECT DATE(CONVERT_TZ(created_at, 'UTC', 'Europe/Berlin')) AS local_day, COUNT(*) AS orders
       FROM orders GROUP BY local_day`,
  );
  return rows;
}
