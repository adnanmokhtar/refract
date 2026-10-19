// Flat config. Restricted imports are the lint half of the rules in .claude/rules/.
export default [
  {
    files: ['**/*.ts', '**/*.tsx'],
    rules: {
      'no-restricted-imports': ['error', { paths: ['moment', 'lodash'] }],
    },
  },
];
