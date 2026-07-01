const { defineConfig } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://localhost:8080';

module.exports = defineConfig({
  testDir: './e2e',
  use: {
    headless: true,
    baseURL,
  },
  projects: [
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
