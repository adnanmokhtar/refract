// Acme Orders — the shared ESLint 10 flat config. Packages lint through this file; a package that
// needs more rules adds an object here instead of keeping a config of its own.
import tseslint from 'typescript-eslint';
import boundaries from 'eslint-plugin-boundaries';
import checkFile from 'eslint-plugin-check-file';
import comments from '@eslint-community/eslint-plugin-eslint-comments';

export default [
  { ignores: ['**/dist/**', '**/*.gen.ts', 'packages/legacy-reports/**'] },
  {
    files: ['apps/**/*.{ts,tsx,vue}', 'packages/**/*.{ts,tsx}'],
    languageOptions: { parser: tseslint.parser },
    plugins: {
      boundaries,
      'check-file': checkFile,
      '@eslint-community/eslint-comments': comments,
      '@typescript-eslint': tseslint.plugin,
    },
    settings: {
      'boundaries/elements': [
        { type: 'route', pattern: 'apps/web/src/routes/**' },
        { type: 'feature', pattern: 'apps/web/src/features/*', capture: ['feature'] },
        { type: 'component', pattern: 'apps/web/src/components/**' },
        { type: 'hook', pattern: 'apps/web/src/hooks/**' },
        { type: 'server', pattern: 'apps/web/src/server/**' },
      ],
    },
    rules: {
      'no-restricted-imports': [
        'error',
        {
          paths: [
            { name: 'ky', message: 'Use @acme/http (apiClient); ADR-0007 covers the PDF stream only.', allowTypeImports: true },
            { name: 'axios', message: 'Use @acme/http (apiClient).' },
            { name: 'dayjs', message: 'Use @acme/format (formatDate, formatRelative).' },
            { name: 'moment', message: 'moment is banned; use @acme/format.' },
          ],
          patterns: [
            { group: ['@radix-ui/*'], message: 'Use @acme/ui (Dialog, Select, Tooltip, Popover, Tabs).' },
            { group: ['@acme/*/src/*', '@acme/*/dist/*', '**/packages/*/src/*'], message: 'Import a workspace package through its entry point.' },
          ],
        },
      ],
      'boundaries/dependencies': [
        'error',
        {
          default: 'disallow',
          policies: [
            { from: ['route'], allow: ['feature', 'component', 'hook'] },
            { from: ['feature'], allow: ['component', 'hook'] },
            { from: ['component'], allow: ['component', 'hook'] },
            { from: ['hook'], allow: ['hook'] },
            { from: ['server'], allow: ['hook'] },
          ],
        },
      ],
      'check-file/filename-naming-convention': ['error', { 'apps/web/src/**/*.tsx': 'PASCAL_CASE' }, { ignoreMiddleExtensions: true }],
      'check-file/folder-naming-convention': ['error', { 'apps/web/src/features/*/': 'KEBAB_CASE' }],
      '@eslint-community/eslint-comments/require-description': ['error', { ignore: [] }],
      '@typescript-eslint/naming-convention': [
        'error',
        { selector: ['variable', 'parameter', 'property'], types: ['boolean'], format: ['PascalCase'], prefix: ['is', 'has', 'should', 'can'] },
      ],
    },
  },
  {
    files: ['apps/web/src/**/*.{ts,tsx}'],
    ignores: ['apps/web/src/server/**'],
    rules: {
      'no-restricted-globals': ['error', { name: 'fetch', message: 'Browser code calls the API through @acme/http.' }],
    },
  },
];
