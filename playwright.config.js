const { defineConfig, devices } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://localhost:8080';

module.exports = defineConfig({
  testDir: './shared/e2e',
  fullyParallel: true,
  use: {
    headless: true,
    baseURL,
    actionTimeout: 5000,
    navigationTimeout: 10000,
  },
  projects: [
    {
      name: 'Desktop Chrome',
      testMatch: ['test.spec.js', 'gemini-generated.spec.js', 'ai-assisted-generated.spec.js'],
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
