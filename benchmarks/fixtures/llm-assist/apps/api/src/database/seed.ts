import { MikroORM } from '@mikro-orm/postgresql';
import { Customer } from '../support/customer.entity';
import { Workspace } from '../support/workspace.entity';

/** Local development data. Deterministic: the same seed gives the same workspace every run. */
const seed = Number(process.env.SEED ?? 42);

function seededRandom(start: number): () => number {
  let state = start;
  return () => {
    state = (state * 1_103_515_245 + 12_345) % 2 ** 31;
    return state / 2 ** 31;
  };
}

async function main() {
  const orm = await MikroORM.init();
  const em = orm.em.fork();
  const rand = seededRandom(seed);
  em.create(Workspace, { id: 'ws_demo', name: 'Northwind Bikes', plan: 'team' });
  for (let i = 0; i < 25; i++) {
    em.create(Customer, {
      id: `cus_${i}`,
      tenantId: 'ws_demo',
      firstName: `Demo${i}`,
      lastName: 'Customer',
      email: `demo${i}@northwind.example`,
      lifetimeValueMinor: Math.round(rand() * 50_000),
    });
  }
  await em.flush();
  await orm.close();
}

void main();
