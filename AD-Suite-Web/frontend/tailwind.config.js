/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                // Primary Orange
                'primary': '#E8500A',
                'primary-light': '#F15A22',

                // Dark Backgrounds
                'bg-dark': '#1A1A1A',
                'bg-darker': '#0D0D0D',
                'bg-primary': '#1A1A1A',
                'bg-secondary': '#0D0D0D',
                'bg-tertiary': '#242422',
                'bg-hover': '#2a2a27',
                'bg-active': '#303030',

                // Text colors
                'text-white': '#FFFFFF',
                'text-gray': '#2C2C2C',
                'text-primary': '#FFFFFF',
                'text-secondary': '#a0a09e',
                'text-tertiary': '#6a6a68',

                // Borders
                'border-light': '#2e2e2b',
                'border-medium': '#3a3a37',

                // Table colors
                'table-header': '#E8500A',
                'table-row-alt': '#F5F5F5',

                // Accent (keeping for compatibility)
                'accent-orange': '#E8500A',
                'accent-orange-hover': '#F15A22',
                'accent-orange-light': '#2a1f1a',

                // Surface
                'surface': '#1A1A1A',
                'surface-elevated': '#242422',

                // Confidential
                'confidential-red': '#CC0000',

                // Severity colors
                'critical': '#f85149',
                'high': '#f0883e',
                'medium': '#d29922',
                'low': '#58a6ff',
                'info': '#8b9cb3',
            },
            fontFamily: {
                sans: ['Inter', 'Open Sans', 'system-ui', 'sans-serif'],
                heading: ['Montserrat', 'Inter', 'sans-serif'],
                mono: ['JetBrains Mono', 'monospace']
            },
            fontSize: {
                'xs': '9pt',
                'sm': '10pt',
                'base': '10pt',
                'md': '11pt',
                'lg': '14pt',
                'xl': '16pt',
                '2xl': '20pt',
                '3xl': '28pt',
            }
        },
    },
    plugins: [],
}
