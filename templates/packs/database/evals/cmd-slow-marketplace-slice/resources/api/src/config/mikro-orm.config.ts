import { defineConfig } from '@mikro-orm/postgresql';
import { Migrator } from '@mikro-orm/migrations';
import { databaseConfig as db } from './database';

export default defineConfig({
  host: db.host,
  port: db.port,
  dbName: db.name,
  user: db.user,
  password: db.password,

  entities: ['dist/**/*.entity.js'],
  entitiesTs: ['src/**/*.entity.ts'],
  extensions: [Migrator],
  debug: process.env.NODE_ENV === 'development' ? ['query'] : false,

  // Reads outside a transaction go to the replica when one is configured.
  replicas: db.replicaHost ? [{ name: 'replica-1', host: db.replicaHost }] : [],

  pool: {
    min: 2,
    max: db.poolMax,
    idleTimeoutMillis: 30_000,
  },

  // Merged into the Knex config: top-level keys go to Knex, `connection` to node-postgres.
  driverOptions: {
    acquireConnectionTimeout: db.poolAcquireTimeoutMs,
    connection: {
      application_name: process.env.HOSTNAME ?? 'stallwise-api',
      idle_in_transaction_session_timeout: db.idleInTransactionTimeoutMs,
    },
  },

  migrations: {
    path: 'dist/migrations',
    pathTs: 'src/migrations',
    transactional: true,
    allOrNothing: false,
    snapshot: false,
  },
});
