import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/debug';
import { dismissPostLoginOverlays } from '../helpers/auth';
import { clickFlutterParagraphMatch, goToRegistrationScreen, scrollFlutterView } from '../helpers/flutter';

test.describe('P1 — Регистрация', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
    const regBtn = await goToRegistrationScreen(page);
    await regBtn.click({ force: true });
    await expect(page.getByText('Регистрация', { exact: true })).toBeVisible({ timeout: 5000 });
  });

  test.skip('регистрация нового пользователя → MainScreen, Профиль', async ({ page }) => {
    const uniqueEmail = `e2e_reg_${Date.now()}@gmail.com`;
    await page.getByText('Имя').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.locator('input').first().fill('Тест');
    await page.getByText('Фамилия').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.locator('input').last().fill('Тестов');
    await scrollFlutterView(page, 700);
    await clickFlutterParagraphMatch(page, /^E-?mail$/i);
    await page.waitForTimeout(400);
    await page.locator('input').last().fill(uniqueEmail);
    await page.getByText('Выберите пол').first().click({ force: true });
    await page.waitForTimeout(500);
    await page.getByText('Мужской').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.getByText('Пароль').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.locator('input').last().fill('password123');
    await page.getByText('Подтвердите пароль').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.locator('input').last().fill('password123');
    await page.getByText(/соглашаюсь/).first().click({ force: true });
    await page.waitForTimeout(200);
    await page.getByText('Создать аккаунт').first().click({ force: true });
    await page.waitForTimeout(3000);
    await dismissPostLoginOverlays(page);
    await expect(page.getByText('Профиль').first()).toBeVisible({ timeout: 15000 });
  });

  test.skip('закрытие модалок после регистрации — Профиль отображается', async ({ page }) => {
    const uniqueEmail = `e2e_reg_${Date.now()}_2@gmail.com`;
    await page.getByText('Имя').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.locator('input').first().fill('Тест');
    await page.getByText('Фамилия').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.locator('input').last().fill('Тестов');
    await scrollFlutterView(page, 700);
    await clickFlutterParagraphMatch(page, /^E-?mail$/i);
    await page.waitForTimeout(400);
    await page.locator('input').last().fill(uniqueEmail);
    await page.getByText('Выберите пол').first().click({ force: true });
    await page.waitForTimeout(500);
    await page.getByText('Мужской').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.getByText('Пароль').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.locator('input').last().fill('password123');
    await page.getByText('Подтвердите пароль').first().click({ force: true });
    await page.waitForTimeout(400);
    await page.locator('input').last().fill('password123');
    await page.getByText(/соглашаюсь/).first().click({ force: true });
    await page.waitForTimeout(200);
    await page.getByText('Создать аккаунт').first().click({ force: true });
    await page.waitForTimeout(2000);
    await dismissPostLoginOverlays(page);
    await expect(page.getByText('Профиль').first()).toBeVisible({ timeout: 15000 });
  });
});
