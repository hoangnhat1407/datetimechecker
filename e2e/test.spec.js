const { test, expect } = require('@playwright/test');
const { testData } = require('./helpers/test-data');

const VALID_COLOR = 'rgb(0, 128, 0)';   // green
const INVALID_COLOR = 'rgb(255, 0, 0)'; // red

async function checkDate(page, day, month, year) {
  await page.fill('#day', day);
  await page.waitForTimeout(500);
  await page.fill('#month', month);
  await page.waitForTimeout(500);
  await page.fill('#year', year);
  await page.waitForTimeout(500);
  await page.click('button');
  await page.waitForTimeout(500);
  return page.locator('#result');
}

for (const tc of testData) {
  test(tc.description, async ({ page }) => {
    await page.goto('/');
    const result = await checkDate(page, tc.day, tc.month, tc.year);
    await expect(result).toHaveCSS('color', tc.expectedValid ? VALID_COLOR : INVALID_COLOR);
  });
}
