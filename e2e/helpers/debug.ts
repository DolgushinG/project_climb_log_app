import { Locator, Page } from '@playwright/test';

/** Ожидание загрузки Flutter-приложения */
export async function waitForAppReady(page: Page) {
  await page.waitForLoadState('networkidle');
  // index.html: после first-frame / fallback #loading получает .hidden и через ~400ms remove().
  // Считать только opacity:0 «скрытым» ненадёжно — ждём исчезновения узла из DOM.
  await page.waitForFunction(() => !document.getElementById('loading'), {
    timeout: 60000,
  });
  await page.waitForTimeout(2000);
}

/** Логирует состояние страницы для отладки (только при DEBUG_E2E=1) */
export async function logPageState(page: Page, label: string) {
  if (!DEBUG_E2E) return;
  const url = page.url();
  const title = await page.title();
  const visibleText = await page.locator('body').innerText().catch(() => '');
  const textPreview = visibleText.slice(0, 500).replace(/\s+/g, ' ');
  console.log(`\n[DEBUG ${label}] URL: ${url} | Title: ${title}`);
  console.log(`[DEBUG ${label}] Visible text (500 chars): ${textPreview}...`);
  const loading = await page.locator('#loading').isVisible().catch(() => false);
  console.log(`[DEBUG ${label}] #loading visible: ${loading}`);
}

export interface ElementLog {
  selector: string;
  count: number;
  visible: number;
  attached: number;
  firstBox?: { x: number; y: number; w: number; h: number };
  firstTag?: string;
}

const DEBUG_E2E = process.env.DEBUG_E2E === '1' || process.env.DEBUG_E2E === 'true';

/** Логирует элементы по селекторам: количество, видимость, boundingBox */
export async function logElements(page: Page, label: string, selectors: Array<{ name: string; locator: Locator }>) {
  if (!DEBUG_E2E) return;
  console.log(`\n[ELEMENTS ${label}]`);
  for (const { name, locator } of selectors) {
    const count = await locator.count();
    let visible = 0;
    let attached = 0;
    let firstBox: { x: number; y: number; w: number; h: number } | undefined;
    let firstTag = '';
    if (count > 0) {
      attached = count;
      for (let i = 0; i < Math.min(count, 3); i++) {
        const n = locator.nth(i);
        if (await n.isVisible().catch(() => false)) visible++;
        if (!firstBox) {
          const box = await n.boundingBox().catch(() => null);
          if (box) {
            firstBox = { x: Math.round(box.x), y: Math.round(box.y), w: Math.round(box.width), h: Math.round(box.height) };
            firstTag = await n.evaluate((el) => el.tagName).catch(() => '');
          }
        }
      }
    }
    console.log(
      `  ${name}: count=${count} visible=${visible} attached=${attached}` +
        (firstBox ? ` first@(${firstBox.x},${firstBox.y}) ${firstBox.w}x${firstBox.h} <${firstTag}>` : ''),
    );
  }
}

/** Дампит все flt-paragraph с текстом, содержащим подстроку */
export async function logParagraphsWithText(page: Page, label: string, substring: string) {
  if (!DEBUG_E2E) return;
  const result = await page.evaluate(
    (sub) => {
      const paras = document.querySelectorAll('flt-paragraph');
      const out: Array<{ text: string; visible: boolean; rect: DOMRect }> = [];
      paras.forEach((p) => {
        const t = (p.textContent || '').trim();
        if (t.includes(sub)) {
          const rect = p.getBoundingClientRect();
          out.push({
            text: t.slice(0, 60),
            visible: rect.width > 0 && rect.height > 0,
            rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
          });
        }
      });
      return out;
    },
    substring,
  );
  console.log(`\n[PARAGRAPHS "${substring}" ${label}] found ${result.length}`);
  result.slice(0, 5).forEach((r, i) =>
    console.log(`  [${i}] "${r.text}" visible=${r.visible} rect=(${r.rect.x},${r.rect.y}) ${r.rect.width}x${r.rect.height}`),
  );
}
