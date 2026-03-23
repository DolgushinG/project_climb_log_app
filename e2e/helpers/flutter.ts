import { Locator, Page } from '@playwright/test';

/**
 * У flt-paragraph часто 0×0 — Playwright не может кликнуть по тексту.
 * Поднимаемся к предку с нормальным rect (поле ввода / semantics) и вызываем click().
 */
export async function clickFlutterParagraphMatch(page: Page, pattern: RegExp) {
  const clicked = await page.evaluate(
    ({ source, flags }) => {
      const re = new RegExp(source, flags);
      const paras = Array.from(document.querySelectorAll('flt-paragraph'));
      for (const p of paras) {
        const t = (p.textContent || '').trim();
        if (!re.test(t)) continue;
        let n: Element | null = p;
        while (n) {
          const r = (n as HTMLElement).getBoundingClientRect();
          if (r.width >= 40 && r.height >= 16) {
            (n as HTMLElement).click();
            return true;
          }
          n = n.parentElement;
        }
        (p as HTMLElement).click();
        return true;
      }
      return false;
    },
    { source: pattern.source, flags: pattern.flags },
  );
  if (!clicked) {
    throw new Error(`clickFlutterParagraphMatch: не найден flt-paragraph для ${pattern}`);
  }
}

/** Прокрутка колесом по области приложения (длинные формы регистрации / логина). */
export async function scrollFlutterView(page: Page, deltaY: number) {
  await page.mouse.move(400, 400);
  await page.mouse.wheel(0, deltaY);
  await page.waitForTimeout(250);
}

/** Flutter HTML: inputs создаются при фокусе. Кликаем по области Email/Пароль чтобы создать input. */
export async function getLoginEmailInput(page: Page): Locator {
  const emailArea = page.getByText('Email').first();
  await emailArea.click({ force: true });
  await page.waitForTimeout(300);
  return page.locator('input').first();
}

export async function getLoginPasswordInput(page: Page): Locator {
  await page.getByText('Пароль').first().click({ force: true });
  await page.waitForTimeout(300);
  return page.locator('input').first();
}

/** Кнопка «Войти» на лендинге. Для гостя: вкладка Профиль показывает экран входа без скролла. */
export function getLandingLoginButton(page: Page): Locator {
  return page.getByText('Войти', { exact: true }).first();
}

/** Переход на экран логина. Гость: 4 вкладки (без Профиль), Войти на лендинге Тренировок — нужен скролл */
export async function goToLoginScreen(page: Page) {
  for (let i = 0; i < 5; i++) {
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(200);
    const loginBtn = page.getByText('Войти', { exact: true }).first();
    if (await loginBtn.isVisible().catch(() => false)) {
      await loginBtn.waitFor({ state: 'visible', timeout: 5000 });
      return loginBtn;
    }
  }
  const loginBtn = page.getByText('Войти', { exact: true }).first();
  await loginBtn.scrollIntoViewIfNeeded({ timeout: 10000 });
  return loginBtn;
}

/** Переход на экран регистрации. Гость: скролл до «Зарегистрироваться» на лендинге */
export async function goToRegistrationScreen(page: Page) {
  for (let i = 0; i < 8; i++) {
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(200);
    const btn = page.getByText('Зарегистрироваться', { exact: true }).first();
    if (await btn.isVisible().catch(() => false)) {
      await btn.waitFor({ state: 'visible', timeout: 5000 });
      return btn;
    }
  }
  const btn = page.getByText('Зарегистрироваться', { exact: true }).first();
  await btn.scrollIntoViewIfNeeded({ timeout: 10000 });
  return btn;
}

/** Кнопка «Вход» (submit) на форме логина. force: true для обхода flutter-view. */
export function getLoginSubmitButton(page: Page): Locator {
  return page.getByRole('button', { name: 'Вход' }).or(
    page.getByText('Вход', { exact: true }).last()
  ).first();
}

/** Отправка формы логина. Клик по кнопке Вход — та, что между «Забыл пароль» и «Гостевой режим». */
export async function submitLoginForm(page: Page) {
  await page.keyboard.press('Enter');
  await page.waitForTimeout(800);
  const stillOnLogin = await page.getByText('Email').first().isVisible().catch(() => false);
  if (stillOnLogin) {
    const guestBtn = page.getByText('Гостевой режим').first();
    const guestBox = await guestBtn.boundingBox().catch(() => null);
    if (guestBox) {
      await page.mouse.click(guestBox.x + guestBox.width / 2, guestBox.y - 50);
    } else {
      await page.getByText('Вход', { exact: true }).nth(1).click({ force: true, timeout: 5000 });
    }
  }
}
