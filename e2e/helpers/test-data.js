const path = require('path');
const fs = require('fs');

// Bộ test case dùng chung cho mọi loại test (sinh từ generate-test-data.js)
const testData = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', '..', 'test-data.json'), 'utf-8')
);

// Subset đại diện các nhóm test case cho mobile (chạy chậm hơn desktop)
const mobileTestCases = testData.filter((_, index) =>
  index < 5 ||                        // ngày đầu tháng
  (index >= 12 && index <= 16) ||     // ngày cuối tháng
  (index >= 24 && index <= 31) ||     // năm nhuận
  (index >= 32 && index <= 36)        // invalid cases
);

module.exports = { testData, mobileTestCases };
