import type { Config } from 'jest';

// End-to-end tests: the real Nest app on Fastify against a Testcontainers Postgres.
const config: Config = {
  rootDir: '.',
  roots: ['<rootDir>/test/e2e'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  testRegex: '\\.e2e-spec\\.ts$',
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.json' }] },
  testEnvironment: 'node',
  testTimeout: 60_000,
};

export default config;
