import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  use: { baseURL: 'http://localhost:4173', storageState: 'e2e/.auth/staff.json' },
  webServer: { command: 'pnpm build && pnpm preview --port 4173', url: 'http://localhost:4173' },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
