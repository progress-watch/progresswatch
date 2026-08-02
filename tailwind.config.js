module.exports = {
  content: [
    './app/javascript/**/*.{js,vue}',
    './app/views/**/*.erb'
  ],
  darkMode: 'media',
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#eef4ff',
          100: '#dae5ff',
          200: '#bdd2ff',
          300: '#90b4ff',
          400: '#5b8bff',
          500: '#3563f5',
          600: '#2145e0',
          700: '#1b36b5',
          800: '#1c3190',
          900: '#1c2d72'
        }
      },
      fontFamily: {
        mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'Monaco', 'Consolas', 'monospace']
      }
    }
  }
}
