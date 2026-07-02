const path = require('path');
const { defineConfig, devices } = require('@playwright/test');

const topicDir = __dirname;
const baseURL = process.env.BASE_URL || 'http://localhost:18080';
const artifactDir = path.join(topicDir, 'visual-artifacts');

module.exports = defineConfig({
  testDir: path.join(topicDir, 'e2e'),
  outputDir: process.env.VISUAL_TEST_RESULTS_DIR || path.join(artifactDir, 'test-results'),
  snapshotPathTemplate: path.join(artifactDir, 'baseline', '{arg}{ext}'),
  reporter: [
    ['list'],
    ['html', {
      outputFolder: process.env.VISUAL_HTML_REPORT_DIR || path.join(artifactDir, 'playwright-report'),
      open: 'never',
    }],
  ],
  use: {
    baseURL,
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [
    {
      name: 'Desktop Chrome',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1366, height: 768 },
      },
    },
  ],
});
