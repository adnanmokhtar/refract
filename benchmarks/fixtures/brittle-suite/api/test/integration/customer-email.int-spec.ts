import { MikroORM } from '@mikro-orm/core';
import { SqliteDriver } from '@mikro-orm/sqlite';
import { Customer } from '../../src/customers/customer.entity';

// Sign-up is idempotent per tenant because (tenant_id, email) is unique.
describe('customer email uniqueness (integration)', () => {
  let orm: MikroORM;

  beforeAll(async () => {
    orm = await MikroORM.init({ driver: SqliteDriver, dbName: ':memory:', entities: [Customer] });
    await orm.schema.createSchema();
  });

  afterAll(() => orm.close());

  it('refuses a second customer with the same email', async () => {
    const em = orm.em.fork();
    em.create(Customer, { tenantId: 'tn_a', email: 'ana@shop.test' });
    await em.flush();

    em.create(Customer, { tenantId: 'tn_a', email: 'ana@shop.test' });
    await expect(em.flush()).rejects.toThrow(/unique/i);
  });

  it('keeps two sign-ups whose emails differ only in case apart', async () => {
    const em = orm.em.fork();
    em.create(Customer, { tenantId: 'tn_a', email: 'Bo@Shop.test' });
    em.create(Customer, { tenantId: 'tn_a', email: 'bo@shop.test' });
    await expect(em.flush()).resolves.not.toThrow();
  });

  it('allows the same email under two tenants', async () => {
    const em = orm.em.fork();
    em.create(Customer, { tenantId: 'tn_a', email: 'cy@shop.test' });
    em.create(Customer, { tenantId: 'tn_b', email: 'cy@shop.test' });
    await expect(em.flush()).resolves.not.toThrow();
  });
});
