import { EntityManager } from '@mikro-orm/postgresql';

/** Platform admin "download a database dump": every table, page by page, each page its own statement. */
export class DbDumpPort {
  constructor(private readonly em: EntityManager) {}

  async *dump(): AsyncGenerator<{ table: string; rows: unknown[] }> {
    const conn = this.em.getConnection();
    const tables = await conn.execute<{ table_name: string }[]>(
      `select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE'`,
    );
    for (const { table_name } of tables) {
      for (let after = ''; ; ) {
        const rows = await conn.execute(`select * from "${table_name}" where id::text > ? order by id limit 1000`, [after]);
        if (rows.length === 0) break;
        yield { table: table_name, rows };
        after = String(rows[rows.length - 1].id);
      }
    }
  }
}
