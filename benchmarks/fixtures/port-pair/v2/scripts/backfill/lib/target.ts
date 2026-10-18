import pg from 'pg';

export interface UpsertOptions {
  // Skip a row when the target already holds a newer version (a live dual write landed first).
  onlyIfOlder?: string;
}

export interface Target {
  insert(table: string, rows: Record<string, unknown>[]): Promise<number>;
  upsert(table: string, rows: Record<string, unknown>[], conflict: string[], opts?: UpsertOptions): Promise<number>;
  exec(sql: string, params?: unknown[]): Promise<number>;
  one<T>(sql: string, params?: unknown[]): Promise<T>;
  resetSequence(table: string, column: string): Promise<void>;
}

export async function openTarget(url = process.env.V2_DATABASE_URL): Promise<Target> {
  const client = new pg.Client({ connectionString: url });
  await client.connect();

  const values = (rows: Record<string, unknown>[]) => {
    const cols = Object.keys(rows[0]);
    const params: unknown[] = [];
    const tuples = rows.map((r) => `(${cols.map((c) => (params.push(r[c]), `$${params.length}`)).join(', ')})`);
    return { cols, params, tuples: tuples.join(', ') };
  };

  return {
    async insert(table, rows) {
      if (!rows.length) return 0;
      const { cols, params, tuples } = values(rows);
      return (await client.query(`INSERT INTO ${table} (${cols.join(', ')}) VALUES ${tuples}`, params)).rowCount ?? 0;
    },
    async upsert(table, rows, conflict, opts = {}) {
      if (!rows.length) return 0;
      const { cols, params, tuples } = values(rows);
      const set = cols.filter((c) => !conflict.includes(c)).map((c) => `${c} = EXCLUDED.${c}`).join(', ');
      const guard = opts.onlyIfOlder ? ` WHERE ${table}.${opts.onlyIfOlder} < EXCLUDED.${opts.onlyIfOlder}` : '';
      return (await client.query(`INSERT INTO ${table} (${cols.join(', ')}) VALUES ${tuples} ON CONFLICT (${conflict.join(', ')}) DO UPDATE SET ${set}${guard}`, params)).rowCount ?? 0;
    },
    async exec(sql, params = []) {
      return (await client.query(sql, params)).rowCount ?? 0;
    },
    async one<T>(sql: string, params: unknown[] = []) {
      return (await client.query(sql, params)).rows[0] as T;
    },
    async resetSequence(table, column) {
      await client.query(`SELECT setval(pg_get_serial_sequence('${table}', '${column}'), COALESCE((SELECT MAX(${column}) FROM ${table}), 1))`);
    },
  };
}
