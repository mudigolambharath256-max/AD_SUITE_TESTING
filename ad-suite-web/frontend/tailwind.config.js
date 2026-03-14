/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'bg-primary': '#1a1612',
        'bg-secondary': '#1e1b18',
        'bg-tertiary': '#262220',
        'bg-surface': '#2d2926',
        'bg-hover': '#312e2b',

        'text-primary': '#ede9e0',
        'text-secondary': '#9b8e7e',
        'text-muted': '#6b5f54',
        'text-placeholder': '#7a6e65',

        'accent-primary': '#d4a96a',
        'accent-hover': '#c9963f',
        'accent-muted': '#2e2318',
        'accent-border': '#5c3d1e',
        'accent-light': '#e0b87a',

        'border': '#3d3530',
        'border-strong': '#4a403a',

        'severity-critical': '#c0392b',
        'severity-high': '#e07b39',
        'severity-medium': '#d4a96a',
        'severity-low': '#4e8c5f',
        'severity-info': '#5b7fa6',
        'status-success': '#4e8c5f',
        'status-warning': '#c9963f',
        'status-error': '#c0392b',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'fade-in': 'fadeIn 150ms ease-in-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        }
      },
      scrollbar: {
        thin: 'thin',
        'auto': 'auto',
        'none': 'none',
      },
      scrollbarWidth: {
        thin: 'thin',
      },
      scrollbarColor: {
        'primary': '#2a2a4a #1a1a2e',
      }
    },
  },
  plugins: [],
}
