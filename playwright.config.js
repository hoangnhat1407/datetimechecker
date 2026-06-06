const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './e2e',
  use: {
    headless: true,
    baseURL: 'http://localhost:8080',
  },
  projects: [
    // Desktop
    {
      name: 'Desktop Chrome',
      testMatch: 'test.spec.js',
      use: { ...devices['Desktop Chrome'] },
    },
    // Mobile - dùng Chromium với viewport iPhone 14 Pro Max
    {
      name: 'iPhone 14 Pro Max',
      testMatch: 'mobile.spec.js',
      use: {
        browserName: 'chromium',
        viewport: { width: 430, height: 932 },
        deviceScaleFactor: 3,
        isMobile: true,
        hasTouch: true,
      },
    },
  ],
});
