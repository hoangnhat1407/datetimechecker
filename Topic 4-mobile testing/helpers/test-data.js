const path = require('path');
const fs = require('fs');

const testData = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', '..', 'test-data.json'), 'utf-8')
);

const mobileTestCases = testData.filter((_, index) =>
  index < 5 ||
  (index >= 12 && index <= 16) ||
  (index >= 24 && index <= 31) ||
  (index >= 32 && index <= 36)
);

module.exports = { testData, mobileTestCases };
