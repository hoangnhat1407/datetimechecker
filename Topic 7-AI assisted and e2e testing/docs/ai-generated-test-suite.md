# AI-generated test suite

Request: generate 5 test cases to test DateTimeChecker
Model: gemini-3.1-flash-lite
Generated at: 2026-07-10T15:52:42.319Z

TC01: Valid standard date [Type: EP]
[Input] Day: "15", Month: "05", Year: "2023"
[Expected] VALID -> "Date is valid"

TC02: Leap year February 29th [Type: BVA]
[Input] Day: "29", Month: "02", Year: "2024"
[Expected] VALID -> "Leap year date is valid"

TC03: Non-leap year February 29th [Type: BVA]
[Input] Day: "29", Month: "02", Year: "2023"
[Expected] INVALID -> "Invalid date for non-leap year"

TC04: Out of range year [Type: BVA]
[Input] Day: "01", Month: "01", Year: "999"
[Expected] INVALID -> "Year below 1000 is invalid"

TC05: Invalid day for month [Type: Error Guessing]
[Input] Day: "31", Month: "04", Year: "2022"
[Expected] INVALID -> "April only has 30 days"
