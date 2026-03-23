import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';

test.describe('P2 — Профиль (просмотр)', () => {
  test.beforeEach(async ({ page }) => { await login(page); });

  test('профиль после логина — имя, карточки', async ({ page }) => {
    await page.getByText('Профиль').last().click({ force: true });
    await page.waitForTimeout(2000);
    await expect(page.getByText('Профиль').last()).toBeVisible({ timeout: 5000 });
    await expect(page.getByText('Изменить данные').or(page.getByText('Город')).first()).toBeVisible({ timeout: 10000 });
  });
});
