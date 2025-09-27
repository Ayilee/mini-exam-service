import globals from 'globals'

export default [
  {
    files: ['**/*.js'],
    ignores: ['node_modules/**', 'coverage/**', 'reports/**'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: { ...globals.node }
    },
    rules: {
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-undef': 'error',
      'semi': ['error', 'never'],
      'quotes': ['error', 'single']
    }
  },
  {
    files: ['__tests__/**/*.js'],
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.jest
      }
    }
  }
]
