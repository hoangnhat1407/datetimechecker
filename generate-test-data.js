const fs = require('fs');

const testCases = [];

// Valid dates - ngày 1 của mỗi tháng
for (let month = 1; month <= 12; month++) {
testCases.push({ day: "1", month: String(month), year: "2000", expectedValid: true });
}

// Ngày cuối mỗi tháng (không nhuận)
const maxDays = [31,28,31,30,31,30,31,31,30,31,30,31];
for (let month = 1; month <= 12; month++) {
testCases.push({ day: String(maxDays[month-1]), month: String(month), year: "2001", expectedValid: true });
}

// Năm nhuận
for (const year of [2000, 2004, 2008, 2400]) {
testCases.push({ day: "29", month: "2", year: String(year), expectedValid: true });
}

// Không nhuận
for (const year of [1900, 2100, 2200, 2300]) {
testCases.push({ day: "29", month: "2", year: String(year), expectedValid: false });
}

// Day out of range
for (const day of [0, 32, 99, -1]) {
testCases.push({ day: String(day), month: "1", year: "2000", expectedValid: false });
}

// Month out of range
for (const month of [0, 13, 99]) {
testCases.push({ day: "1", month: String(month), year: "2000", expectedValid: false });
}

// Year out of range
for (const year of [999, 3001, 0]) {
testCases.push({ day: "1", month: "1", year: String(year), expectedValid: false });
}

// Input không phải số
for (const val of ["abc", "", " ", "1.5", "!@#"]) {
testCases.push({ day: val, month: "1", year: "2000", expectedValid: false });
testCases.push({ day: "1", month: val, year: "2000", expectedValid: false });
testCases.push({ day: "1", month: "1", year: val,    expectedValid: false });
}

fs.writeFileSync('test-data.json', JSON.stringify(testCases, null, 2));
console.log(`Generated ${testCases.length} test cases`);