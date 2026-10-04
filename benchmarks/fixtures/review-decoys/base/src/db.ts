import pg from 'pg';

export const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 20 });

export const db = {
  query: (text: string, params: unknown[] = []) => pool.query(text, params).then((r) => r.rows),
  transaction: async <T>(fn: (q: typeof pool.query) => Promise<T>): Promise<T> => {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const out = await fn(client.query.bind(client));
      await client.query('COMMIT');
      return out;
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  },
};
