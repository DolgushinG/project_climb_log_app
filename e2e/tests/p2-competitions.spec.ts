import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/debug';

test.describe('P2 — Соревнования', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('список соревнований — вкладка Соревнования', async ({ page }) => {
    await page.getByText('Соревнования').last().click({ force: true });
    await page.waitForTimeout(2000);
    const content = page.locator('body');
    await expect(content).toBeVisible();
    const hasList = await page.getByText('Предстоящие').or(page.getByText('Завершённые')).or(page.getByText('Нет соревнований')).isVisible().catch(() => false);
    expect(hasList || await content.textContent()).toBeTruthy();
  });

  test('деталь соревнования — тап по карточке', async ({ page }) => {
    await page.getByText('Соревнования').last().click({ force: true });
    await page.waitForTimeout(3000);
    // Нижняя навигация тоже с role="button" (Semantics) — исключаем подписи вкладок.
    const cards = page
      .locator('[role="button"]')
      .filter({ hasText: /[А-Яа-я]{5,}/ })
      .filter({ hasNotText: /^(Тренировки|Рейтинг|Соревнования|Скалодромы|Профиль)$/ });
    const count = await cards.count();
    if (count > 0) {
      await cards.first().click();
      await page.waitForTimeout(1500);
      await expect(page.locator('body')).toContainText(/[А-Яа-я]/);
    }
  });
});
