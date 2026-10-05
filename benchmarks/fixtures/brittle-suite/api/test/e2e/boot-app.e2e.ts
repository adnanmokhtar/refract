import { Test } from '@nestjs/testing';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { PostgreSqlContainer, StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { AppModule } from '../../src/app.module';

// Shared bootstrap for the e2e suites: one Postgres container per file, the real module graph.
// Not a test file — it declares no cases; each *.e2e-spec.ts imports it.
export interface BootedApp {
  app: NestFastifyApplication;
  db: StartedPostgreSqlContainer;
}

export async function bootApp(overrides: (builder: ReturnType<typeof Test.createTestingModule>) => void = () => undefined): Promise<BootedApp> {
  const db = await new PostgreSqlContainer('postgres:16-alpine').start();
  process.env.DATABASE_HOST = db.getHost();
  process.env.DATABASE_NAME = db.getDatabase();
  process.env.DATABASE_USER = db.getUsername();
  process.env.DATABASE_PASSWORD = db.getPassword();

  const builder = Test.createTestingModule({ imports: [AppModule] });
  overrides(builder);
  const moduleRef = await builder.compile();
  const app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
  await app.init();
  await app.getHttpAdapter().getInstance().ready();
  return { app, db };
}

export const asAgent = (tenant: string, roles = 'agent') => ({
  'x-test-tenant': tenant,
  'x-test-agent': `agent_${tenant}`,
  'x-test-roles': roles,
});
