import { Pool } from 'pg';
import { MikroORM } from '@mikro-orm/postgresql';

/**
 * Entry point of the api-migrate Job (deploy/k8s/migrate-job.yaml): takes a cluster-wide advisory lock so two
 * overlapping rollouts never migrate at once, then runs the MikroORM migrator.
 */
async function main(): Promise<void> {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 4 });
  await pool.query('SELECT pg_advisory_lock(72707369)');
  try {
    const orm = await MikroORM.init();
    await orm.getMigrator().up();
    await orm.close();
  } finally {
    await pool.query('SELECT pg_advisory_unlock(72707369)');
    await pool.end();
  }
}

void main();
