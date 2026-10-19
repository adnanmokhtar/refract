/** Architecture rules for the API (ADR 0002). Run: npx depcruise src --config .dependency-cruiser.cjs */
module.exports = {
  forbidden: [
    {
      name: 'domain-is-framework-free',
      comment: 'ADR 0002: api/src/domain imports nothing from Nest, Prisma or any I/O library.',
      severity: 'error',
      from: { path: '^src/domain' },
      to: { path: 'node_modules/(@nestjs|@prisma|prisma|pg|axios)' },
    },
    {
      name: 'domain-does-not-reach-out',
      severity: 'error',
      from: { path: '^src/domain' },
      to: { path: '^src/(?!domain)' },
    },
    {
      name: 'no-circular',
      severity: 'warn',
      from: {},
      to: { circular: true },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsConfig: { fileName: 'tsconfig.json' },
  },
};
