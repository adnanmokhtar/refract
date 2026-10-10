#!/usr/bin/env ts-node
// One-shot developer helper: `npm run seed:dev` fills a local database with demo orders.
// Nothing in deploy/ runs it; it never ships in the production image (dist/ only).
import { MikroORM } from '@mikro-orm/postgresql';
import config from '../src/mikro-orm.config';

async function main(): Promise<void> {
  const orm = await MikroORM.init(config);
  const em = orm.em.fork();
  for (let i = 0; i < 25; i++) {
    em.create('Order', { reference: `DEV-${1000 + i}`, totalCents: 1999 + i * 100, status: 'placed' });
  }
  await em.flush();
  console.log('seeded 25 demo orders into', config.dbName);
  await orm.close();
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
