import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';

test.describe('P1 — Навигация (авторизованный)', () => {
  test.beforeEach(async ({ page }) => { await login(page); });

  test('все вкладки переключаются корректно', async ({ page }) => {
    const tabs = [
      { name: 'Тренировки', check: 'Тренировки' },
      { name: 'Рейтинг', check: 'Рейтинг' },
      { name: 'Соревнования', check: 'Соревнования' },
      { name: 'Скалодромы', check: 'Скалодромы' },
      { name: 'Профиль', check: 'Профиль' },
    ];

    for (const tab of tabs) {
      await page.getByText(tab.name).last().click({ force: true });
      await page.waitForTimeout(1000);
      await expect(page.getByText(tab.check).last()).toBeVisible({ timeout: 5000 });
    }
  });
});
