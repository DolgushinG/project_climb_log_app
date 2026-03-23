import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/debug';
import { goToLoginScreen, goToRegistrationScreen } from '../helpers/flutter';

test.describe('P2 — Гость → Войти → LoginScreen', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('переход на логин — Гость → Войти → LoginScreen', async ({ page }) => {
    const loginBtn = await goToLoginScreen(page);
    await loginBtn.click({ force: true });
    await expect(page.getByText('Вход', { exact: true }).first()).toBeVisible({ timeout: 5000 });
    await page.getByText('Email').first().click({ force: true });
    await page.waitForTimeout(300);
    await expect(page.locator('input').first()).toBeVisible({ timeout: 5000 });
  });

  test('переход на регистрацию — Гость → Зарегистрироваться → RegistrationScreen', async ({ page }) => {
    const regBtn = await goToRegistrationScreen(page);
    await regBtn.click({ force: true });
    await expect(page.getByText('Регистрация', { exact: true })).toBeVisible({ timeout: 5000 });
    await expect(page.getByText('Имя').or(page.getByLabel('Имя')).first()).toBeAttached({ timeout: 5000 });
    await expect(page.getByText('Создать аккаунт').or(page.getByRole('button', { name: 'Создать аккаунт' })).first()).toBeAttached({ timeout: 5000 });
  });
});
