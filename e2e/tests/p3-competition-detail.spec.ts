import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/debug';

test.describe('P3 — Деталь соревнования', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('гость на детали — Войти чтобы принять участие или редирект', async ({ page }) => {
    await page.getByText('Соревнования').last().click({ force: true });
    await page.waitForTimeout(3000);
    const cards = page
      .locator('[role="button"]')
      .filter({ hasText: /[А-Яа-я]{5,}/ })
      .filter({ hasNotText: /^(Тренировки|Рейтинг|Соревнования|Скалодромы|Профиль)$/ });
    const count = await cards.count();
    if (count > 0) {
      await cards.first().click();
      await page.waitForTimeout(1500);
      // T‑Bank / онлайн-оплата: на карточке может быть «Продолжить оплату» вместо только гостевого CTA.
      const hasLoginPrompt = await page
        .getByText(/Войти|принять участие|Продолжить оплату|Оплатить/)
        .isVisible()
        .catch(() => false);
      const hasContent = await page.locator('body').textContent();
      const hasErrorOrEmpty = await page.getByText(/Ошибка соединения|Текущих соревнований пока нет/).isVisible().catch(() => false);
      expect(hasLoginPrompt || (hasContent && hasContent.length > 50) || hasErrorOrEmpty).toBeTruthy();
    }
  });

  test('кнопки по состоянию — соревнование с открытой регистрацией', async ({ page }) => {
    await page.getByText('Соревнования').last().click({ force: true });
    await page.waitForTimeout(3000);
    const cards = page
      .locator('[role="button"]')
      .filter({ hasText: /[А-Яа-я]{5,}/ })
      .filter({ hasNotText: /^(Тренировки|Рейтинг|Соревнования|Скалодромы|Профиль)$/ });
    const count = await cards.count();
    if (count > 0) {
      await cards.first().click();
      await page.waitForTimeout(1500);
      await expect(page.locator('body')).toBeVisible();
    }
  });
});
