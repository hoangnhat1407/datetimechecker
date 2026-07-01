const fs = require('fs');
const path = require('path');
const { test, expect } = require('@playwright/test');

const topicDir = path.resolve(__dirname, '..');
const currentDir = process.env.VISUAL_CURRENT_DIR ||
  path.join(topicDir, 'visual-artifacts', 'current');

function screenshotPath(name) {
  return path.join(currentDir, name);
}

async function preparePage(page) {
  await page.goto('/');
  await page.addStyleTag({
    content: `
      *, *::before, *::after {
        animation-duration: 0s !important;
        animation-delay: 0s !important;
        transition-duration: 0s !important;
        transition-delay: 0s !important;
        caret-color: transparent !important;
      }
    `,
  });
  await page.waitForLoadState('networkidle');
}

async function captureAndCompare(page, fileName) {
  fs.mkdirSync(currentDir, { recursive: true });
  await page.screenshot({
    path: screenshotPath(fileName),
    fullPage: true,
    animations: 'disabled',
  });

  await expect(page).toHaveScreenshot(fileName, {
    fullPage: true,
    animations: 'disabled',
    maxDiffPixelRatio: 0.01,
  });
}

test.describe('DateTimeChecker visual regression', () => {
  test('home page empty form', async ({ page }) => {
    await preparePage(page);
    await captureAndCompare(page, 'home-empty.png');
  });

  test('valid date result state', async ({ page }) => {
    await preparePage(page);
    await page.fill('#day', '29');
    await page.fill('#month', '2');
    await page.fill('#year', '2024');
    await page.click('button');
    await expect(page.locator('#result')).toContainText(/is a valid date/i);
    await captureAndCompare(page, 'valid-date-result.png');
  });

  test('invalid date result state', async ({ page }) => {
    await preparePage(page);
    await page.fill('#day', '31');
    await page.fill('#month', '2');
    await page.fill('#year', '2024');
    await page.click('button');
    await expect(page.locator('#result')).toContainText(/is an invalid date/i);
    await captureAndCompare(page, 'invalid-date-result.png');
  });
});
