import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [react()],
    server: {
        port: 5173,
        /** Listen on all interfaces so other devices on the LAN can open http://<this-pc-ip>:5173 */
        host: true,
        proxy: {
            '/api': {
                target: 'http://localhost:3000',
                changeOrigin: true
            },
            '/health': {
                target: 'http://localhost:3000',
                changeOrigin: true
            }
        }
    }
});
