import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/debug';
import { goToLoginScreen } from '../helpers/flutter';

test.describe('P1 — Главный экран (гость)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('загрузка приложения — видны вкладки и контент Тренировок', async ({ page }) => {
    await page.waitForTimeout(2000);
    const tab = page.getByRole('button', { name: 'Тренировки' }).or(page.getByText('Тренировки').last());
    await expect(tab).toBeVisible({ timeout: 15000 });
    await expect(page.getByRole('button', { name: 'Соревнования' }).or(page.getByText('Соревнования').last())).toBeVisible();
    await expect(page.getByRole('button', { name: 'Рейтинг' }).or(page.getByText('Рейтинг').last())).toBeVisible();
    await expect(page.getByRole('button', { name: 'Скалодромы' }).or(page.getByText('Скалодромы').last())).toBeVisible();
  });

  test.skip('переключение на вкладку Соревнования', async ({ page }) => {
    await page.getByText('Соревнования').last().click({ force: true });
    await page.waitForTimeout(500);
    await expect(page.getByText('Соревнования').last()).toBeVisible();
  });

  test('переключение на вкладку Рейтинг', async ({ page }) => {
    await page.getByText('Рейтинг').last().click({ force: true });
    await page.waitForTimeout(500);
    await expect(page.getByText('Рейтинг').last()).toBeVisible();
  });

  test('переключение на вкладку Скалодромы', async ({ page }) => {
    await page.getByText('Скалодромы').last().click({ force: true });
    await page.waitForTimeout(1000);
    await expect(page.getByText('Скалодромы').last()).toBeVisible();
  });

  test('гость — кнопка Войти (вкладка Профиль → LoginScreen)', async ({ page }) => {
    const loginBtn = await goToLoginScreen(page);
    await loginBtn.click({ force: true });
    await page.waitForTimeout(1000);
    await expect(page.getByText('Вход', { exact: true }).first()).toBeVisible({ timeout: 5000 });
    await expect(page.getByText('Email').first()).toBeVisible();
    await page.getByText('Email').first().click({ force: true });
    await page.waitForTimeout(300);
    await expect(page.locator('input').first()).toBeVisible({ timeout: 5000 });
  });
});
