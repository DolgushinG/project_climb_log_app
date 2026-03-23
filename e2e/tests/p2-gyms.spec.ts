import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/debug';

test.describe('P2 — Скалодромы', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('список скалодромов — вкладка Скалодромы', async ({ page }) => {
    await page.getByText('Скалодромы').last().click({ force: true });
    await page.waitForTimeout(3000);
    await expect(page.getByText('Список скалодромов').or(page.getByText('Все')).first()).toBeVisible({ timeout: 10000 });
  });

  test('поиск — ввод в поле поиска', async ({ page }) => {
    await page.getByText('Скалодромы').last().click({ force: true });
    await page.waitForTimeout(3000);
    await expect(page.getByText('Все').first()).toBeVisible({ timeout: 10000 });
    const inpCount = await page.locator('input').count();
    if (inpCount > 0) {
      await page.locator('input').first().click({ force: true });
      await page.locator('input').first().fill('Москва');
    }
  });
});
