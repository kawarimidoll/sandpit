import antfu from '@antfu/eslint-config';

export default antfu({
  /* options */
  lessopinionated: true,
  formatters: true,
  svelte: true,

  /* general rules */
  rules: {
    'eqeqeq': ['error', 'always', { null: 'ignore' }],
    'no-unexpected-multiline': 'error',
    'no-unreachable': 'error',
    'curly': ['error', 'all'],
    'antfu/top-level-function': 'error',
    // this is not important because unused-imports/no-unused-vars is enabled
    'no-unused-vars': 'off',
    // apply 'no-console' only '.svelte' files in each project
    'no-console': 'off',
  },

  /* style rules */
  stylistic: {
    semi: true,
  },
}, {
  // apply 'no-console' only '.svelte' files
  files: ['**/*.svelte'],
  rules: { 'no-console': 'error' },
});
