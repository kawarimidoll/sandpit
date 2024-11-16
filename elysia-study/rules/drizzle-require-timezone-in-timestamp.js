/***
 * example
 * ```js
 * // bad
 * timestamp();
 * // good
 * timestamp({ precision: 6, withTimezone: true });
 * // good
 * timestamp("created_at" { withTimezone: true });
 * ```
 */

const message = '`timestamp` must have `withTimezone: true`.'
export const requireTimezoneInTimestamp = {
  meta: {
    type: 'problem',
    docs: {
      description: 'Ensure `timestamp` has `withTimezone: true`',
      category: 'Best Practices',
      recommended: true,
    },
    fixable: 'code',
    schema: [],
  },

  create(context) {
    return {
      CallExpression(node) {
        if (node.callee.name !== 'timestamp') {
          return
        }

        // report timestamp()
        if (node.arguments.length === 0) {
          context.report({
            node,
            message,
            fix(fixer) {
              return fixer.replaceText(
                node,
                'timestamp({ withTimezone: true })',
              )
            },
          })
          return
        }

        // report timestamp('name')
        if (
          node.arguments.length === 1
          && node.arguments[0].type !== 'ObjectExpression'
        ) {
          context.report({
            node,
            message,
            fix(fixer) {
              return fixer.insertTextAfter(
                node.arguments[0],
                ', { withTimezone: true }',
              )
            },
          })
          return
        }

        // maybe length is 1 or 2
        const objArg = node.arguments.length === 1
          ? node.arguments[0]
          : node.arguments[1]

        // report timestamp({})
        // report timestamp('name', {})
        if (objArg.properties.length === 0) {
          context.report({
            node,
            message,
            fix(fixer) {
              return fixer.replaceText(
                objArg,
                '{ withTimezone: true }',
              )
            },
          })
          return
        }

        const timezoneProp = objArg.properties.find(
          prop => prop.key.name === 'withTimezone',
        )
        if (!timezoneProp) {
          // report timestamp({ other: 'foo' })
          // report timestamp('name', { other: 'foo' })
          const lastProperty = objArg.properties.at(-1)
          context.report({
            node,
            message,
            fix(fixer) {
              return fixer.insertTextAfterRange(lastProperty.range, ', withTimezone: true')
            },
          })
        }
        else if (timezoneProp.value.value !== true) {
          // report timestamp({ withTimezone: 'foo' })
          // report timestamp({ withTimezone: false })
          // report timestamp('name', { withTimezone: false })
          context.report({
            node,
            message,
            fix(fixer) {
              return fixer.replaceText(timezoneProp.value, 'true')
            },
          })
        }
      },
    }
  },
}

export const plugin = {
  rules: { 'require-timezone-in-timestamp': requireTimezoneInTimestamp },
}
