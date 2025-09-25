export default [
  {
    files: ['**/*.js'],
    ignores: ['node_modules/**', 'coverage/**'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module'
    },
    env: {
      node: true
    },
    rules: {
      'no-unused-vars': ['error', { 'argsIgnorePattern': '^_' }],
      'no-undef': 'error',
      'semi': ['error', 'never'],
      'quotes': ['error', 'single']
    }
  },
  {
    files: ['__tests__/**/*.js'],
    env: {
      node: true,
      jest: true
    }
  }
]
