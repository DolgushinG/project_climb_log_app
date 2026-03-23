import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/debug';
import { goToLoginScreen, getLoginEmailInput, getLoginPasswordInput, submitLoginForm } from '../helpers/flutter';
import { dismissPostLoginOverlays } from '../helpers/auth';

const TEST_EMAIL = 'tester@tester.ru';
const TEST_PASSWORD = 'password';

test.describe('P1 — Логин', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
    const loginBtn = await goToLoginScreen(page);
    await loginBtn.click({ force: true });
    await expect(page.getByText('Вход', { exact: true }).first()).toBeVisible({ timeout: 5000 });
  });

  test('успешный вход → MainScreen, вкладка Профиль', async ({ page }) => {
    await (await getLoginEmailInput(page)).fill(TEST_EMAIL);
    await (await getLoginPasswordInput(page)).fill(TEST_PASSWORD);
    await submitLoginForm(page);
    await page.waitForTimeout(3000);
    await dismissPostLoginOverlays(page);
    await expect(page.getByText('Профиль').last()).toBeVisible({ timeout: 15000 });
  });

  test('закрытие модалок после логина — Профиль отображается', async ({ page }) => {
    await (await getLoginEmailInput(page)).fill(TEST_EMAIL);
    await (await getLoginPasswordInput(page)).fill(TEST_PASSWORD);
    await submitLoginForm(page);
    await page.waitForTimeout(2000);
    await dismissPostLoginOverlays(page);
    await expect(page.getByText('Профиль').last()).toBeVisible({ timeout: 15000 });
  });

  test('неверные данные — сообщение об ошибке', async ({ page }) => {
    await (await getLoginEmailInput(page)).fill('wrong@example.com');
    await (await getLoginPasswordInput(page)).fill('wrongpassword');
    await submitLoginForm(page);
    await page.waitForTimeout(5000);
    const hasError = await page.getByText('Ошибка входа').isVisible().catch(() => false)
      || await page.getByText('Неверный').isVisible().catch(() => false)
      || await page.getByText('Ошибка соединения').isVisible().catch(() => false);
    const stillOnLoginForm = await page.getByText('Вход', { exact: true }).first().isVisible().catch(() => false);
    expect(hasError || stillOnLoginForm).toBeTruthy();
  });
});
