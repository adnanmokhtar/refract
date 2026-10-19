import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    // Development only: the API and the files service run on their own ports locally.
    proxy: {
      '/api/files': { target: 'http://localhost:8081', rewrite: (p) => p.replace(/^\/api\/files/, '') },
      '/api': 'http://localhost:3000',
    },
  },
});
