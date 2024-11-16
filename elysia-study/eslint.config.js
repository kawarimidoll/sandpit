import antfu from '@antfu/eslint-config'
import { FlatCompat } from '@eslint/eslintrc'

import { plugin as drizzlePlugin } from './rules/drizzle-require-timezone-in-timestamp.js'

const compat = new FlatCompat()

export default antfu(
  {
    rules: {
      'no-console': ['off'],
      'antfu/no-top-level-await': ['off'],
    },
  },
  // Legacy config
  ...compat.config({
    extends: ['plugin:drizzle/recommended'],
  }),
  {
    plugins: { drizzlePlugin },
    rules: {
      'drizzlePlugin/require-timezone-in-timestamp': 'error',
    },
  },
)
