/** Design-token enforcement for app CSS (tokens: packages/ui/src/tokens.css). */
export default {
  plugins: ['stylelint-declaration-strict-value'],
  ignoreFiles: ['packages/ui/src/tokens.css', 'apps/web/emails/**', 'packages/legacy-reports/**'],
  rules: {
    'scale-unlimited/declaration-strict-value': [
      ['/color$/', 'background', 'padding', 'margin', 'gap', 'font-size'],
      {
        ignoreValues: ['transparent', 'inherit', 'currentColor', 'none', '0', 'auto'],
        severity: 'warning',
      },
    ],
  },
};
