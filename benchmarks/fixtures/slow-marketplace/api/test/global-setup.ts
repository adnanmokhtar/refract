import { MikroORM } from '@mikro-orm/postgresql';
import ormConfig from '../src/config/mikro-orm.config';

// Migrates the disposable e2e database (TEST_DATABASE_* env, never a shared one).
export default async function globalSetup() {
  const orm = await MikroORM.init({ ...ormConfig, dbName: process.env.TEST_DATABASE_NAME ?? 'stallwise_e2e', replicas: [] });
  await orm.getMigrator().up();
  await orm.close();
}
