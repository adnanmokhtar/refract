import type { Config } from 'jest';

// Unit tests: colocated with the code under src/, one *.spec.ts per service.
const config: Config = {
  rootDir: '.',
  roots: ['<rootDir>/src'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  testRegex: '.*\\.spec\\.ts$',
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.json' }] },
  testEnvironment: 'node',
  clearMocks: true,
  collectCoverageFrom: ['src/**/*.ts', '!src/main.ts', '!src/**/*.module.ts'],
  coveragePathIgnorePatterns: ['/node_modules/', '<rootDir>/src/billing/'],
  coverageThreshold: { global: { lines: 80, branches: 70 } },
};

export default config;
