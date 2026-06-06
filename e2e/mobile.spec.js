const { test, expect } = require('@playwright/test');
const path = require('path');
const fs = require('fs');

const MOBILE_URL = 'http://localhost:8080/mobile/index.html';

// Dùng chung test data với các test khác
const testData = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'test-data.json'), 'utf-8')
);

// Subset đại diện các nhóm test case
const mobileTestCases = testData.filter((_, index) =>
  index < 5 ||                        // ngày đầu tháng
  (index >= 12 && index <= 16) ||     // ngày cuối tháng
  (index >= 24 && index <= 31) ||     // năm nhuận
  (index >= 32 && index <= 36)        // invalid cases
);

test.describe('Mobile - Flutter Web (DateTimeChecker)', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto(MOBILE_URL);
    await page.waitForLoadState('domcontentloaded');
  });

  // --- Test 1: Kiểm tra Flutter app load ---
  test('Flutter app load thành công trên mobile', async ({ page }) => {
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 15000 });
    await expect(page.locator('flt-glass-pane')).toBeAttached();
    expect(page.url()).toContain('/mobile/');
  });

  // --- Test 2: Kiểm tra API từ mobile context ---
  test('API trả kết quả đúng từ mobile context', async ({ page }) => {
    const result = await page.evaluate(async () => {
      const res = await fetch('/api/datetime/check', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ day: '15', month: '6', year: '2000' }),
      });
      return res.json();
    });
    expect(result.valid).toBe(true);
  });

  // --- Test 3+: Chạy toàn bộ test cases từ test-data.json qua mobile browser ---
  for (const tc of mobileTestCases) {
    test(`[Mobile] ${tc.description}`, async ({ page }) => {
      const apiResponse = await page.evaluate(async ({ day, month, year }) => {
        const res = await fetch('/api/datetime/check', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ day, month, year }),
        });
        return res.json();
      }, { day: tc.day, month: tc.month, year: tc.year });

      expect(apiResponse.valid).toBe(tc.expectedValid);
    });
  }

});
