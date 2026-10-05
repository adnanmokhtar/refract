import { test, expect } from '@playwright/test';

test.describe('refund drawer states', () => {
  test.beforeEach(async ({ page }) => {
    await page.route('**/api/admin/orders?*', (route) =>
      route.fulfill({ json: { items: [{ id: 'o1', number: 'L-1001', customer: 'Ada', total: 12900, status: 'paid' }], pages: 1 } }),
    );
    await page.goto('/orders');
    await page.getByText('L-1001').click();
  });

  test('offline refund is rejected with a message', async ({ page, context }) => {
    await context.setOffline(true);
    await page.getByLabel('Amount').fill('10');
    await page.getByLabel('Reason').fill('Damaged');
    await page.getByRole('button', { name: 'Refund' }).click();
    await expect(page.getByRole('alert')).toContainText(/offline/i);
  });

  test('refund amount over the total is rejected', async ({ page }) => {
    await page.getByLabel('Amount').fill('500');
    await page.getByLabel('Amount').blur();
    await expect(page.getByLabel('Amount')).toHaveAccessibleDescription(/up to the order total/i);
  });

  test('refund asks for confirmation', async ({ page }) => {
    await page.getByLabel('Amount').fill('10');
    await page.getByLabel('Reason').fill('Damaged');
    await page.getByRole('button', { name: 'Refund' }).click();
    await expect(page.getByRole('dialog', { name: /cannot be undone/i })).toBeVisible();
  });
});
