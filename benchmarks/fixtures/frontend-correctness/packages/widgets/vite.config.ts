import { defineConfig } from 'vite';
import legacy from '@vitejs/plugin-legacy';

// The embed loader runs on partner recipe sites, some of which still see old Safari and Samsung Internet.
// plugin-legacy emits a separate nomodule bundle for those; modern browsers load only the module chunks.
export default defineConfig({
  build: { outDir: 'dist/loader', lib: { entry: 'src/loader.ts', formats: ['es'], fileName: 'harbor-loader' } },
  plugins: [legacy({ targets: ['defaults', 'safari >= 12', 'samsung >= 12'], renderModernChunks: true })],
});
