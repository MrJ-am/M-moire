const { defineConfig, devices } = require('@playwright/test');
const { createHash } = require('node:crypto');
const origin = process.env.TEST_ORIGIN || 'http://127.0.0.1:4173';
const launchOptions = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE, args: ['--no-sandbox', '--disable-dev-shm-usage'] } : {};

module.exports = defineConfig({
  testDir: './tests/e2e',
  timeout: 30000,
  workers: 1,
  retries: 0,
  maxFailures: process.env.CI ? 5 : 0,
  reporter: [['list']],
  use: {
    baseURL: `${origin}/matheval/`,
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  webServer: {
    command: 'node ../server/src/index.mjs',
    url: `${origin}/matheval/api/health`,
    reuseExistingServer: !process.env.CI,
    env: { ...process.env, PORT: '4173', PUBLIC_ORIGIN: origin, BASE_PATH: '/matheval', NODE_ENV: 'test', DATABASE_URL: process.env.BROWSER_DATABASE_URL || 'postgres://postgres@127.0.0.1:55432/matheval_browser_test', ADMIN_SETUP_TOKEN_HASH: createHash('sha256').update('a'.repeat(64)).digest('hex') },
    timeout: 30000
  },
  projects: [
    {
      name: 'firefox',
      testIgnore: '**/*.touch.spec.js',
      use: {
        ...devices['Desktop Firefox'],
        browserName: 'firefox'
      }
    },
    {
      name: 'chromium',
      testMatch: ['**/survey-gestures.spec.js', '**/collection-admin.spec.js'],
      use: { ...devices['Desktop Chrome'], browserName: 'chromium', launchOptions }
    },
    {
      name: 'chromium-touch',
      testMatch: '**/*.touch.spec.js',
      use: { browserName: 'chromium', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, launchOptions }
    }
  ]
});
