import { defineConfig } from '@mikro-orm/postgresql';

export default defineConfig({
  clientUrl: process.env.DATABASE_URL,
  dbName: 'harbor',
  entities: ['dist/**/*.entity.js'],
  entitiesTs: ['src/**/*.entity.ts'],
  pool: { min: 2, max: 20 },
});
