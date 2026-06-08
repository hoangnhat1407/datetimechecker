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

  // --- Test 1.5: Demo nhập liệu đầy đủ (Day/Month/Year) + ấn Check trực tiếp trên canvas Flutter ---
  // Flutter Web dùng renderer CanvasKit nên UI vẽ lên <canvas>, không có
  // input DOM như #day/#month/#year để page.fill() như test.spec.js, và vị
  // trí các field còn xê dịch theo bàn phím ảo nên không thể bấm theo toạ độ
  // cố định. Thay vào đó dùng phím Tab để di chuyển focus tuần tự giữa các ô
  // (Flutter Web hỗ trợ keyboard traversal chuẩn) rồi gõ từng ký tự.
  async function fillAndCheckOnCanvas(page, day, month, year) {
    // Tăng timeout vì khi chạy --headed tuần tự nhiều case, mỗi case phải
    // load lại app Flutter từ đầu (beforeEach) -> dễ chậm hơn 15s do tải dồn
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 30000 });
    await page.waitForTimeout(1000); // chờ Flutter render xong UI

    // Tab -> ô "Day"
    await page.keyboard.press('Tab');
    await page.keyboard.type(day, { delay: 150 });
    await page.waitForTimeout(400);

    // Tab -> ô "Month"
    await page.keyboard.press('Tab');
    await page.keyboard.type(month, { delay: 150 });
    await page.waitForTimeout(400);

    // Tab -> ô "Year"
    await page.keyboard.press('Tab');
    await page.keyboard.type(year, { delay: 150 });
    await page.waitForTimeout(400);

    // Tab -> nút "Check", Enter để bấm
    await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(1500); // chờ kết quả hiển thị trên canvas
  }

  // Demo trên toàn bộ subset mobile (mobileTestCases) - cùng bộ dữ liệu
  // được sinh ra từ generate-test-data.js -> test-data.json
  for (const tc of mobileTestCases) {
    test(`[Demo canvas] ${tc.description}`, async ({ page }) => {
      test.setTimeout(60000); // thao tác canvas + load lại app mỗi case khá chậm khi chạy tuần tự
      await fillAndCheckOnCanvas(page, tc.day, tc.month, tc.year);

      const safeName = tc.description.replace(/[^a-zA-Z0-9]+/g, '-');
      await page.screenshot({ path: `test-results/mobile-canvas-${safeName}.png` });
    });
  }

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
    await page.waitForTimeout(800); // dừng lại để xem kết quả khi demo
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
      await page.waitForTimeout(800); // dừng lại để xem kết quả khi demo
    });
  }

});
