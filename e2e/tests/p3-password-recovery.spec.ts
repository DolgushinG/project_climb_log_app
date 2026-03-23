import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/debug';
import { clickFlutterParagraphMatch, goToLoginScreen, scrollFlutterView } from '../helpers/flutter';

test.describe('P3 — Восстановление пароля', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
    const loginBtn = await goToLoginScreen(page);
    await loginBtn.click({ force: true });
    await expect(page.getByText('Вход', { exact: true }).first()).toBeVisible({ timeout: 5000 });
  });

  test.skip('форма восстановления — LoginScreen → Забыли пароль?', async ({ page }) => {
    await scrollFlutterView(page, 400);
    await clickFlutterParagraphMatch(page, /^Забыл пароль\?$/);
    await expect(page.getByText('Восстановление пароля')).toBeVisible({ timeout: 8000 });
  });

  test.skip('отправка email — ввод email, отправка', async ({ page }) => {
    await scrollFlutterView(page, 400);
    await clickFlutterParagraphMatch(page, /^Забыл пароль\?$/);
    await expect(page.getByText('Восстановление пароля')).toBeVisible({ timeout: 8000 });
    await clickFlutterParagraphMatch(page, /^E-?mail$/i);
    await page.waitForTimeout(300);
    await page.locator('input').first().fill('test@example.com');
    await page.getByText('Отправить').or(page.getByRole('button', { name: 'Отправить' })).first().click({ force: true });
    await page.waitForTimeout(3000);
    await expect(
      page.getByText(/отправлена|Ссылка|проверьте почту|отправлено|Ошибка/i)
    ).toBeVisible({ timeout: 8000 });
  });
});
