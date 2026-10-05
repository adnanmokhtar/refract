import { PGlite } from '@electric-sql/pglite';

// Real Postgres SQL in-process: the balance view is one statement on one connection, so PGlite's
// single-connection engine is a faithful stand-in for the production server here.
describe('merchant balance view (integration)', () => {
  const db = new PGlite();

  beforeAll(async () => {
    await db.exec(`
      create table ledger_entry (merchant_id text not null, kind text not null check (kind in ('credit','debit')), cents bigint not null check (cents > 0));
      create view merchant_balance as
        select merchant_id, sum(case kind when 'credit' then cents else -cents end) as balance_cents
        from ledger_entry group by merchant_id;
    `);
  });

  afterAll(() => db.close());

  it('nets credits and debits per merchant', async () => {
    await db.exec(`insert into ledger_entry values ('m_1','credit',5000), ('m_1','debit',1200), ('m_2','credit',300)`);
    const { rows } = await db.query<{ merchant_id: string; balance_cents: string }>('select * from merchant_balance order by merchant_id');
    expect(rows).toEqual([
      { merchant_id: 'm_1', balance_cents: '3800' },
      { merchant_id: 'm_2', balance_cents: '300' },
    ]);
  });

  it('rejects a zero-cent entry', async () => {
    await expect(db.exec(`insert into ledger_entry values ('m_1','debit',0)`)).rejects.toThrow(/check/);
  });
});
