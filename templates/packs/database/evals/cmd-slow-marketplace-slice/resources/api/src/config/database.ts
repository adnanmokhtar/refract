// Every database setting the API and the worker read, in one place. Values come from the
// environment (deploy/k8s/*.yaml and the stallwise-api-env secret).

const int = (name: string, fallback: number): number => {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 0) throw new Error(`${name} must be a non-negative integer`);
  return value;
};

const required = (name: string): string => {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
};

export const databaseConfig = {
  host: required('DATABASE_HOST'),
  replicaHost: process.env.DATABASE_REPLICA_HOST,
  port: int('DATABASE_PORT', 5432),
  name: process.env.DATABASE_NAME ?? 'stallwise',
  user: required('DATABASE_USER'),
  password: required('DATABASE_PASSWORD'),

  // Pool size per process. The deployment sets it (DB_POOL_MAX).
  poolMax: int('DB_POOL_MAX', 10),
  poolAcquireTimeoutMs: int('DB_POOL_ACQUIRE_TIMEOUT_MS', 5_000),

  // Session limits.
  statementTimeoutMs: int('DB_STATEMENT_TIMEOUT_MS', 15_000),
  idleInTransactionTimeoutMs: int('DB_IDLE_IN_TX_TIMEOUT_MS', 30_000),
};

export type DatabaseConfig = typeof databaseConfig;
