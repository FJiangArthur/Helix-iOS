import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

const coreContract = fileURLToPath(new URL('../conversate-core', import.meta.url));

export default defineConfig({
  base: './',
  publicDir: false,
  resolve: { alias: { '@core-contract': coreContract } },
  server: { fs: { allow: ['.', coreContract] } },
  build: { outDir: 'dist', emptyOutDir: true, target: 'es2020' },
  test: { include: ['test/**/*.test.ts'], environment: 'node' },
});
