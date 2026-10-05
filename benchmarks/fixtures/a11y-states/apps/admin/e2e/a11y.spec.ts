import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const routes = ['/orders', '/customers', '/invoices', '/reports', '/settings'];

for (const route of routes) {
  test(`axe: ${route}`, async ({ page }) => {
    await page.goto(route);
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .disableRules(['color-contrast', 'region', 'label', 'button-name'])
      .analyze();
    expect(results.violations).toEqual([]);
  });
}
