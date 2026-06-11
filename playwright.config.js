const { defineConfig, devices } = require('@playwright/test');

// Cho phép override khi chạy trong Docker (BASE_URL=http://app:8080)
const baseURL = process.env.BASE_URL || 'http://localhost:8080';

module.exports = defineConfig({
  testDir: './e2e',
  use: {
    headless: true,
    baseURL,
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
