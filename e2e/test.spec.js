const { test, expect } = require('@playwright/test');
const path = require('path');
const fs = require('fs');

const BASE_URL = 'http://localhost:8080';

// Đọc toàn bộ test case từ file dùng chung
const testData = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'test-data.json'), 'utf-8')
);

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
    await page.goto(BASE_URL);
    const result = await checkDate(page, tc.day, tc.month, tc.year);

    if (tc.expectedValid) {
      await expect(result).toHaveCSS('color', 'rgb(0, 128, 0)');
    } else {
      await expect(result).toHaveCSS('color', 'rgb(255, 0, 0)');
    }
  });
}
