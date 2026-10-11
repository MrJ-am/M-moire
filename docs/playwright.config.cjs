const { defineConfig, devices } = require('@playwright/test');
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
  // Le serveur et PostgreSQL isolés sont possédés par la commande centrale
  // tests/matheval-navigateur.py. Aucun backend Node lancé par Playwright.
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
      testMatch: ['**/survey.spec.js', '**/survey-gestures.spec.js', '**/navigation-libre.spec.js', '**/collection-admin.spec.js', '**/style-mrjam.spec.js', '**/portage-complet.spec.js', '**/cartes-continuite.spec.js', '**/lecteur-commun.spec.js', '**/espace-commun.spec.js'],
      use: { ...devices['Desktop Chrome'], browserName: 'chromium', launchOptions }
    },
    {
      name: 'chromium-touch',
      testMatch: '**/*.touch.spec.js',
      use: { browserName: 'chromium', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, launchOptions }
    }
  ]
});
