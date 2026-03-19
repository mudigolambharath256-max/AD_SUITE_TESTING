import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Get backend URL from environment variable or use localhost as default
const BACKEND_URL = process.env.VITE_BACKEND_URL || 'http://localhost:3001';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',  // Listen on all network interfaces
    port: 5173,
    proxy: {
      '/api': {
        target: BACKEND_URL,
        changeOrigin: true,
      },
      '/terminal': {
        target: BACKEND_URL.replace('http', 'ws'),
        ws: true,
        changeOrigin: true,
      },
    }
  },
  build: {
    outDir: 'dist',
    sourcemap: true
  }
})
