import { test, expect } from '@playwright/test';

test.describe('checkout states', () => {
  test('shows a skeleton while the cart loads', async ({ page }) => {
    await page.route('**/api/cart', () => new Promise(() => {}));
    await page.goto('/en/checkout');
    await expect(page.getByRole('status', { name: /loading/i })).toBeVisible();
  });

  test('empty cart offers a way back to the shop', async ({ page }) => {
    await page.route('**/api/cart', (route) => route.fulfill({ json: { lines: [] } }));
    await page.goto('/en/checkout');
    await expect(page.getByRole('link', { name: /shop the autumn edit/i })).toBeVisible();
  });

  test('one order per double click', async ({ page }) => {
    let posts = 0;
    await page.route('**/api/orders', async (route) => {
      posts += 1;
      await new Promise((r) => setTimeout(r, 500));
      await route.fulfill({ json: { id: 'o_1' } });
    });
    await page.goto('/en/checkout');
    await page.getByRole('button', { name: /place order/i }).dblclick();
    expect(posts).toBe(1);
  });
});
