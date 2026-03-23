import { Page } from '@playwright/test';
import { waitForAppReady } from './debug';
import { goToLoginScreen, getLoginEmailInput, getLoginPasswordInput, submitLoginForm } from './flutter';

const TEST_EMAIL = 'tester@tester.ru';
const TEST_PASSWORD = 'password';

export async function login(page: Page) {
  await page.goto('/');
  await waitForAppReady(page);
  const loginBtn = await goToLoginScreen(page);
  await loginBtn.click({ force: true });
  await page.waitForTimeout(1000);
  await page.getByText('Вход', { exact: true }).first().waitFor({ state: 'visible', timeout: 5000 });
  await (await getLoginEmailInput(page)).fill(TEST_EMAIL);
  await (await getLoginPasswordInput(page)).fill(TEST_PASSWORD);
  await submitLoginForm(page);
  await page.waitForTimeout(3000);
  await dismissPostLoginOverlays(page);
}

export async function dismissPostLoginOverlays(page: Page) {
  await page.waitForTimeout(2000);
  const notNowBtn = page.getByText('Не сейчас', { exact: true });
  try {
    await notNowBtn.first().waitFor({ state: 'visible', timeout: 5000 });
    await notNowBtn.first().click({ force: true });
    await page.waitForTimeout(800);
  } catch (_) {}
  const buttons = ['Начать', 'Позже', 'Не сейчас'];
  for (let i = 0; i < 15; i++) {
    let found = false;
    for (const text of buttons) {
      const btn = page.getByRole('button', { name: text }).or(page.getByText(text, { exact: true }));
      if (await btn.first().isVisible().catch(() => false)) {
        await btn.first().click({ force: true });
        await page.waitForTimeout(800);
        found = true;
        break;
      }
    }
    if (!found) break;
  }
}
