import { expect, test } from '@playwright/test';

// The back office signs an idle agent out after 30 s in the e2e build (VITE_IDLE_TIMEOUT_MS=30000).
// Real time on purpose: this checks the browser's own idle timer against the real session API.
test('an idle agent is signed out after the idle timeout', async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto('/returns');
  const started = Date.now();

  await expect(page.getByRole('heading', { name: 'Signed out' })).toBeVisible({ timeout: 60_000 });
  const elapsedMs = Date.now() - started;

  expect(elapsedMs).toBeGreaterThan(25_000);
  expect(elapsedMs).toBeLessThan(55_000);
});
