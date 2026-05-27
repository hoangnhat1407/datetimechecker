const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './e2e',
  use: {
    headless: false,
    baseURL: 'http://localhost:8080',
  },
});
