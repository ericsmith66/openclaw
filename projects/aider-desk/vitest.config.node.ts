import { resolve } from 'path';

import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    env: {
      AIDER_DESK_NODE_TESTING: 'true',
    },
    include: [
      'src/main/**/__tests__/**/*.{test,spec}.{ts,tsx}',
      'src/preload/**/__tests__/**/*.{test,spec}.{ts,tsx}',
      'src/common/**/__tests__/**/*.{test,spec}.{ts,tsx}',
    ],
    exclude: ['node_modules', 'dist', 'out'],
    setupFiles: ['./src/main/__tests__/setup.ts'],
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src/main'),
      '@common': resolve(__dirname, 'src/common'),
    },
  },
  plugins: [
    tsconfigPaths({
      projects: [resolve(__dirname, 'tsconfig.node.json')],
    }),
  ],
});
