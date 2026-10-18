import { defineConfig } from '@mikro-orm/postgresql';

export default defineConfig({
  clientUrl: process.env.DATABASE_URL,
  entities: ['dist/**/*.entity.js'],
  entitiesTs: ['src/**/*.entity.ts'],
  migrations: { path: 'dist/migrations', pathTs: 'src/migrations', snapshotName: '.snapshot-norrow' },
  timezone: '+00:00',
});
