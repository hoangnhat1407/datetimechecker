const { defineConfig, devices } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://localhost:8080';

module.exports = defineConfig({
  testDir: './e2e',
  use: {
    headless: true,
    baseURL,
  },
  projects: [
    {
      name: 'Desktop Chrome',
      testMatch: ['gemini-generated.spec.js', 'ai-assisted-generated.spec.js'],
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
