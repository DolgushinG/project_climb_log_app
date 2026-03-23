import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/debug';

test.describe('P3 — Рейтинг', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('экран рейтинга — вкладка Рейтинг', async ({ page }) => {
    await page.getByText('Рейтинг').last().click({ force: true });
    await page.waitForTimeout(2000);
    const body = page.locator('body');
    await expect(body).toContainText(/Рейтинг|Мужчины|Женщины|Топ|рейтинг/i);
  });
});
