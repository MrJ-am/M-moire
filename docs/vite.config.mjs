import { defineConfig } from 'vite';
export default defineConfig({
  root: 'site',
  base: '/matheval/',
  server: { host: '0.0.0.0', port: 4173, strictPort: true, allowedHosts: ['terminal.local'], proxy: { '/matheval/api': 'http://127.0.0.1:3000' } }
});
