import mysql from 'mysql2/promise';

// Read-only reader over the V1 MySQL replica (never the primary).
export interface Source {
  page<T>(table: string, afterId: number, limit: number, where?: string): Promise<T[]>;
  query<T>(sql: string, params?: unknown[]): Promise<T[]>;
}

export async function openSource(url = process.env.V1_REPLICA_URL): Promise<Source> {
  const conn = await mysql.createConnection({ uri: url, timezone: '+03:00', dateStrings: true });
  return {
    async page<T>(table: string, afterId: number, limit: number, where?: string) {
      const filter = where ? ` AND (${where})` : '';
      const [rows] = await conn.query(`SELECT * FROM \`${table}\` WHERE id > ?${filter} ORDER BY id LIMIT ?`, [afterId, limit]);
      return rows as T[];
    },
    async query<T>(sql: string, params: unknown[] = []) {
      const [rows] = await conn.query(sql, params);
      return rows as T[];
    },
  };
}
