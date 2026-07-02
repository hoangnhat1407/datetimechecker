# AI-generated test suite

Request: generate 5 test case
Model: gemini-3.1-flash-lite
Generated at: 2026-07-02T01:14:03.233Z

TC01: Valid standard date [Type: EP]
[Input] Day: "15", Month: "06", Year: "2023"
[Expected] VALID -> "valid: true"

TC02: Leap year February 29th [Type: BVA]
[Input] Day: "29", Month: "02", Year: "2024"
[Expected] VALID -> "valid: true"

TC03: Non-leap year February 29th [Type: BVA]
[Input] Day: "29", Month: "02", Year: "2023"
[Expected] INVALID -> "valid: false, field: day"

TC04: Out of range year [Type: BVA]
[Input] Day: "01", Month: "01", Year: "999"
[Expected] INVALID -> "valid: false, field: year"

TC05: Invalid month value [Type: Error Guessing]
[Input] Day: "10", Month: "13", Year: "2020"
[Expected] INVALID -> "valid: false, field: month"
