import { expect, test } from '@playwright/test';

test.describe('refund request', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/returns/ret_seed_1');
  });

  test('an agent approves a return and sees the confirmation', async ({ page }) => {
    await page.getByRole('button', { name: 'Approve return' }).click();
    await page.getByLabel('Note to shopper').fill('Approved — label attached.');
    await page.getByRole('button', { name: 'Send' }).click();
    expect(page.getByText('Saved')).toBeVisible();
  });

  test('the refund amount follows the selected lines', async ({ page }) => {
    await page.getByRole('checkbox', { name: 'Stoneware mug' }).check();
    await page.waitForTimeout(800);
    await expect(page.getByTestId('refund-amount')).toHaveText('€9.00');
  });

  test('a rejected return shows the reason row', async ({ page }) => {
    await page.getByRole('button', { name: 'Reject return' }).click();
    await page.getByRole('combobox', { name: 'Reason' }).selectOption('outside-window');
    await page.getByRole('button', { name: 'Confirm' }).click();
    const reasonRow = page.getByRole('row', { name: /Outside the return window/ });
    expect(await reasonRow.isVisible()).toBe(true);
  });
});
