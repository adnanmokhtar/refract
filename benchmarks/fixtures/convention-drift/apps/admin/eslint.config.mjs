// Admin lint config, kept separate while the Vue parser setup settles.
import vue from 'eslint-plugin-vue';
import tseslint from 'typescript-eslint';

export default [
  ...vue.configs['flat/recommended'],
  {
    files: ['src/**/*.{ts,vue}'],
    languageOptions: { parserOptions: { parser: tseslint.parser } },
    rules: {
      'vue/multi-word-component-names': 'off',
      'no-restricted-imports': 'off',
    },
  },
];
