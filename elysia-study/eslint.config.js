import antfu from '@antfu/eslint-config'
import { FlatCompat } from '@eslint/eslintrc'

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
)
