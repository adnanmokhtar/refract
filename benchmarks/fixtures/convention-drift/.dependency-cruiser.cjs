/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: 'no-app-to-app',
      severity: 'error',
      comment: 'Apps share code through packages/, never through each other.',
      from: { path: '^apps/([^/]+)/' },
      to: { path: '^apps/', pathNot: '^apps/$1/' },
    },
    {
      name: 'packages-not-to-apps',
      severity: 'error',
      from: { path: '^packages/' },
      to: { path: '^apps/' },
    },
    {
      name: 'no-legacy-reports-in-new-code',
      severity: 'error',
      comment: 'ADR-0009: packages/legacy-reports is frozen; nothing new may import it.',
      from: { path: '^apps/' },
      to: { path: '^packages/legacy-reports/' },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsConfig: { fileName: 'tsconfig.base.json' },
  },
};
