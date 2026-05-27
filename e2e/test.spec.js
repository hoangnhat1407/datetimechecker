const { test, expect } = require('@playwright/test');

const BASE_URL = 'http://localhost:8080';

async function checkDate(page, day, month, year) {
  await page.fill('#day', day);
  await page.waitForTimeout(1000);
  await page.fill('#month', month);
  await page.waitForTimeout(1000);
  await page.fill('#year', year);
  await page.waitForTimeout(1000);
  await page.click('button');
  await page.waitForTimeout(1000);
  return page.locator('#result');
}

test('valid date shows green message', async ({ page }) => {
  await page.goto(BASE_URL);
  const result = await checkDate(page, '1', '1', '2000');
  await expect(result).toHaveCSS('color', 'rgb(0, 128, 0)');
  await expect(result).toContainText('valid');
});

test('29/2/2000 is valid (leap year)', async ({ page }) => {
  await page.goto(BASE_URL);
  const result = await checkDate(page, '29', '2', '2000');
  await expect(result).toHaveCSS('color', 'rgb(0, 128, 0)');
});

test('29/2/1900 is invalid (not leap year)', async ({ page }) => {
  await page.goto(BASE_URL);
  const result = await checkDate(page, '29', '2', '1900');
  await expect(result).toHaveCSS('color', 'rgb(255, 0, 0)');
});

test('invalid day shows red message', async ({ page }) => {
  await page.goto(BASE_URL);
  const result = await checkDate(page, 'abc', '1', '2000');
  await expect(result).toHaveCSS('color', 'rgb(255, 0, 0)');
  await expect(result).toContainText('Day');
});

test('31/4/2023 is invalid', async ({ page }) => {
  await page.goto(BASE_URL);
  const result = await checkDate(page, '31', '4', '2023');
  await expect(result).toHaveCSS('color', 'rgb(255, 0, 0)');
});
