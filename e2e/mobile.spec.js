const { test, expect } = require('@playwright/test');
const { mobileTestCases } = require('./helpers/test-data');

const MOBILE_PATH = '/mobile/index.html';

// Gọi API check từ trong page (mobile browser context) và trả về JSON
function checkViaApi(page, { day, month, year }) {
  return page.evaluate(async ({ day, month, year }) => {
    const res = await fetch('/api/datetime/check', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ day, month, year }),
    });
    return res.json();
  }, { day, month, year });
}

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

  for (const value of [day, month, year]) {
    await page.keyboard.press('Tab'); // sang ô Day/Month/Year kế tiếp
    await page.keyboard.type(value, { delay: 150 });
    await page.waitForTimeout(400);
  }

  // Tab -> nút "Check", Enter để bấm
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(1500); // chờ kết quả hiển thị trên canvas
}

test.describe('Mobile - Flutter Web (DateTimeChecker)', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto(MOBILE_PATH);
    await page.waitForLoadState('domcontentloaded');
  });

  test('Flutter app load thành công trên mobile', async ({ page }) => {
    await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 15000 });
    await expect(page.locator('flt-glass-pane')).toBeAttached();
    expect(page.url()).toContain('/mobile/');
  });

  // Demo nhập liệu trực tiếp trên canvas Flutter - cùng bộ dữ liệu
  // được sinh ra từ generate-test-data.js -> test-data.json
  for (const tc of mobileTestCases) {
    test(`[Demo canvas] ${tc.description}`, async ({ page }) => {
      test.setTimeout(60000); // thao tác canvas + load lại app mỗi case khá chậm khi chạy tuần tự
      await fillAndCheckOnCanvas(page, tc.day, tc.month, tc.year);

      const safeName = tc.description.replace(/[^a-zA-Z0-9]+/g, '-');
      await page.screenshot({ path: `test-results/mobile-canvas-${safeName}.png` });
    });
  }

  test('API trả kết quả đúng từ mobile context', async ({ page }) => {
    const result = await checkViaApi(page, { day: '15', month: '6', year: '2000' });
    expect(result.valid).toBe(true);
    await page.waitForTimeout(800); // dừng lại để xem kết quả khi demo
  });

  // Chạy subset test cases từ test-data.json qua mobile browser
  for (const tc of mobileTestCases) {
    test(`[Mobile] ${tc.description}`, async ({ page }) => {
      const apiResponse = await checkViaApi(page, tc);
      expect(apiResponse.valid).toBe(tc.expectedValid);
      await page.waitForTimeout(800); // dừng lại để xem kết quả khi demo
    });
  }

});
