const { test, expect } = require('@playwright/test');
const { testData } = require('./helpers/test-data');

const VALID_COLOR = 'rgb(0, 128, 0)';   // green
const INVALID_COLOR = 'rgb(255, 0, 0)'; // red

async function checkDate(page, day, month, year) {
  await page.fill('#day', day);
  await page.fill('#month', month);
  await page.fill('#year-id', year);
  await page.click('button.btn-primary');
  return page.locator('#result');
}

for (const tc of testData) {
  test(tc.description, async ({ page }) => {
    await page.goto('/');
    const result = await checkDate(page, tc.day, tc.month, tc.year);
    await expect(result).toHaveCSS('color', tc.expectedValid ? VALID_COLOR : INVALID_COLOR);
  });
}
