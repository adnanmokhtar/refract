import pg from 'pg';
import { env } from '../env.js';

export const pool = new pg.Pool({ connectionString: env.DATABASE_URL, max: 10 });

export const repo = {
  async findOne(table: string, id: string): Promise<Record<string, unknown> | undefined> {
    const { rows } = await pool.query(`select * from ${table} where id = $1`, [id]);
    return rows[0];
  },
};
