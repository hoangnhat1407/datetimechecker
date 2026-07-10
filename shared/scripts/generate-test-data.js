const fs = require('fs');

const testCases = [];

// Valid dates - ngày 1 của mỗi tháng
for (let month = 1; month <= 12; month++) {
  testCases.push({
    day: "1", month: String(month), year: "2000",
    expectedValid: true, expectedField: null,
    description: `Ngày đầu tháng: 1/${month}/2000 - hợp lệ`
  });
}

// Ngày cuối mỗi tháng (2001 - không nhuận)
const maxDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
for (let month = 1; month <= 12; month++) {
  testCases.push({
    day: String(maxDays[month - 1]), month: String(month), year: "2001",
    expectedValid: true, expectedField: null,
    description: `Ngày cuối tháng: ${maxDays[month - 1]}/${month}/2001 - hợp lệ`
  });
}

// Năm nhuận hợp lệ - 29/2
for (const year of [2000, 2004, 2008, 2400]) {
  testCases.push({
    day: "29", month: "2", year: String(year),
    expectedValid: true, expectedField: null,
    description: `29/2/${year} - năm nhuận hợp lệ`
  });
}

// Không phải năm nhuận - 29/2 không hợp lệ
for (const year of [1900, 2100, 2200, 2300]) {
  testCases.push({
    day: "29", month: "2", year: String(year),
    expectedValid: false, expectedField: null,
    description: `29/2/${year} - không phải năm nhuận, không hợp lệ`
  });
}

// Day ngoài phạm vi [1-31]
for (const day of [0, 32, 99, -1]) {
  testCases.push({
    day: String(day), month: "1", year: "2000",
    expectedValid: false, expectedField: "day",
    description: `Day = ${day} - ngoài phạm vi [1-31]`
  });
}

// Month ngoài phạm vi [1-12]
for (const month of [0, 13, 99]) {
  testCases.push({
    day: "1", month: String(month), year: "2000",
    expectedValid: false, expectedField: "month",
    description: `Month = ${month} - ngoài phạm vi [1-12]`
  });
}

// Year ngoài phạm vi [1000-3000]
for (const year of [999, 3001, 0]) {
  testCases.push({
    day: "1", month: "1", year: String(year),
    expectedValid: false, expectedField: "year",
    description: `Year = ${year} - ngoài phạm vi [1000-3000]`
  });
}

// Input không phải số nguyên hợp lệ
for (const val of ["abc", "", " ", "1.5", "!@#"]) {
  const display = val === "" ? '""' : val === " " ? '" "' : `"${val}"`;
  testCases.push({
    day: val, month: "1", year: "2000",
    expectedValid: false, expectedField: "day",
    description: `Day = ${display} - không phải số nguyên`
  });
  testCases.push({
    day: "1", month: val, year: "2000",
    expectedValid: false, expectedField: "month",
    description: `Month = ${display} - không phải số nguyên`
  });
  testCases.push({
    day: "1", month: "1", year: val,
    expectedValid: false, expectedField: "year",
    description: `Year = ${display} - không phải số nguyên`
  });
}

fs.mkdirSync('shared/data', { recursive: true });
fs.writeFileSync('shared/data/test-data.json', JSON.stringify(testCases, null, 2));
console.log(`Generated ${testCases.length} test cases`);
