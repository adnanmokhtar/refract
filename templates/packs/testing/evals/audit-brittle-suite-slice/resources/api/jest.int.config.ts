import type { Config } from 'jest';

// Repository-level integration tests: SQL behaviour of the persistence layer.
const config: Config = {
  rootDir: '.',
  roots: ['<rootDir>/test/integration'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  testRegex: '\\.int-spec\\.ts$',
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.json' }] },
  testEnvironment: 'node',
};

export default config;
