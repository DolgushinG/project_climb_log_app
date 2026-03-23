import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.BASE_URL || 'http://localhost:8080';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI
    ? 'github'
    : process.env.ALLURE
      ? [['list'], ['allure-playwright', { resultsDir: 'allure-results' }], ['html', { outputFolder: 'playwright-report' }]]
      : [['list'], ['html', { outputFolder: 'playwright-report' }]],
  use: {
    baseURL,
    trace: 'on',
    screenshot: 'on',
    video: 'on',
    headless: process.env.HEADED === '1',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  timeout: 90000,
  expect: {
    timeout: 10000,
  },
});
