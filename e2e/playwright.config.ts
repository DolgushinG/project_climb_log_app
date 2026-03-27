import { defineConfig, devices } from '@playwright/test';

const baseURL = (process.env.BASE_URL || 'http://localhost:8080').replace(/\/$/, '');
/** Отключить авто-сервер: PW_NO_WEB_SERVER=1 (свой reverse-proxy / уже поднят serve). */
const skipWebServer = process.env.PW_NO_WEB_SERVER === '1' || process.env.PW_NO_WEB_SERVER === 'true';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: process.env.CI ? 1 : undefined,
  ...(skipWebServer
    ? {}
    : {
        webServer: {
          // Важен порядок: иначе serve воспринимает -p не так и уходит на случайный порт.
          command: 'npx serve -p 8080 ../build/web',
          url: baseURL,
          reuseExistingServer: true,
          timeout: 120000,
        },
      }),
  reporter: process.env.CI
    ? 'github'
    : process.env.ALLURE
      ? [['list'], ['allure-playwright', { resultsDir: 'allure-results' }], ['html', { outputFolder: 'playwright-report' }]]
      : [['list'], ['html', { outputFolder: 'playwright-report' }]],
  use: {
    baseURL: `${baseURL}/`,
    trace: 'on',
    screenshot: 'on',
    video: 'on',
    // По умолчанию headless; окно браузера: HEADED=1 npm run test:all
    headless: process.env.HEADED !== '1',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  timeout: 90000,
  expect: {
    timeout: 10000,
  },
});
