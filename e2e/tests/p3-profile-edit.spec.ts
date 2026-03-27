import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { logPageState, logElements, logParagraphsWithText } from '../helpers/debug';

test.describe('P3 — Профиль: редактирование', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.setViewportSize({ width: 1280, height: 1400 });
  });

  test('сохранение — изменение имени, сохранение', async ({ page }) => {
    await page.getByText('Профиль').last().click({ force: true });
    await page.waitForTimeout(2000);
    await logPageState(page, 'BEFORE_CLICK_PROFILE_EDIT');
    await logElements(page, 'BEFORE_CLICK', [
      { name: 'Изменить данные', locator: page.getByText('Изменить данные') },
      { name: 'Изменить данные (exact)', locator: page.getByText('Изменить данные', { exact: true }) },
      { name: 'в листе ожидания', locator: page.getByText('в листе ожидания') },
    ]);
    await logParagraphsWithText(page, 'BEFORE', 'Изменить');
    // exact: на соревновании — «Изменить данные в листе ожидания»; в профиле карточка — только «Изменить данные».
    const btn = page.getByText('Изменить данные', { exact: true }).first();
    const coords = await btn.evaluate((el: HTMLElement) => {
      let target: Element | null = el;
      while (target && target.tagName !== 'BODY') {
        const r = target.getBoundingClientRect();
        if (r.width >= 40 && r.width <= 500 && r.height >= 40 && r.height <= 100) {
          return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
        }
        target = target.parentElement;
      }
      const re = el.getBoundingClientRect();
      return { x: re.x + 80, y: re.y + 20 };
    });
    await page.mouse.click(coords.x, coords.y);
    await page.waitForTimeout(2000);
    await logPageState(page, 'AFTER_CLICK_EDIT_OPEN');
    await logElements(page, 'AFTER_CLICK', [
      { name: 'Изменение данных профиля', locator: page.getByText('Изменение данных профиля') },
      { name: 'Имя', locator: page.getByLabel('Имя') },
    ]);
    await page.waitForTimeout(2000);
    await expect(page.getByText('Изменение данных профиля').or(page.getByText('Имя')).first()).toBeVisible({ timeout: 10000 });
    await page.waitForTimeout(1000);
    // Flutter: input создаётся при фокусе. Кликаем по "Имя" и берём первый input.
    await page.getByText('Имя').first().click({ force: true });
    await page.waitForTimeout(300);
    const nameField = page.locator('input').first();
    await nameField.fill('ТестОбновлён');
    await page.getByText('Сохранить').or(page.getByRole('button', { name: 'Сохранить' })).first().click({ force: true });
    await page.waitForTimeout(3000);
    await expect(page.getByText('Профиль').first()).toBeVisible({ timeout: 5000 });
  });

  test('открытие редактирования — Профиль → Изменить данные', async ({ page }) => {
    await page.getByText('Профиль').last().click({ force: true });
    await page.waitForTimeout(2000);
    await logPageState(page, 'OPEN_TEST_BEFORE_CLICK');
    await logElements(page, 'OPEN_BEFORE', [
      { name: 'Изменить данные', locator: page.getByText('Изменить данные') },
      { name: 'Изменить данные (exact)', locator: page.getByText('Изменить данные', { exact: true }) },
      { name: 'Город', locator: page.getByText('Город') },
    ]);
    await logParagraphsWithText(page, 'OPEN_BEFORE', 'Изменить');
    const btn = page.getByText('Изменить данные', { exact: true }).first();
    let btnInfo = 'none';
    try {
      btnInfo = await btn.evaluate((el) => `${el.tagName}: "${(el as HTMLElement).textContent?.slice(0, 50)}"`);
    } catch (e) {
      btnInfo = `err: ${(e as Error).message}`;
    }
    if (process.env.DEBUG_E2E) console.log(`[OPEN] clicking: ${btnInfo}`);
    // flt-paragraph 0x0. Ищем ближайшего родителя 40–400px по высоте (карточка), не весь scroll.
    const coords = await btn.evaluate((el: HTMLElement) => {
      let target: Element | null = el;
      while (target && target.tagName !== 'BODY') {
        const r = target.getBoundingClientRect();
        if (r.width >= 40 && r.width <= 500 && r.height >= 40 && r.height <= 100) {
          return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
        }
        target = target.parentElement;
      }
      return { x: el.getBoundingClientRect().x + 50, y: el.getBoundingClientRect().y + 10 };
    });
    if (process.env.DEBUG_E2E) console.log(`[OPEN] mouse.click at (${coords.x}, ${coords.y})`);
    await page.mouse.click(coords.x, coords.y);
    await page.waitForTimeout(2000);
    await logPageState(page, 'OPEN_TEST_AFTER_CLICK');
    await logElements(page, 'OPEN_AFTER', [
      { name: 'Изменение данных профиля', locator: page.getByText('Изменение данных профиля') },
      { name: 'Имя', locator: page.getByText('Имя') },
      { name: 'Имя label', locator: page.getByLabel('Имя') },
    ]);
    await expect(page.getByText('Изменение данных профиля').or(page.getByText('Имя')).first()).toBeVisible({ timeout: 8000 });
  });
});
