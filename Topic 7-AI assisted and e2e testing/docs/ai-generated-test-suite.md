# AI-generated test suite

Request: create 6 test cases
Model: gemini-3.1-flash-lite
Generated at: 2026-07-01T17:17:06.933Z

TC01: Valid standard date [Type: EP]
[Input] Day: "15", Month: "05", Year: "2023"
[Expected] VALID -> "Date is valid"

TC02: Leap year February 29 [Type: BVA]
[Input] Day: "29", Month: "02", Year: "2024"
[Expected] VALID -> "Leap year date is valid"

TC03: Non-leap year February 29 [Type: BVA]
[Input] Day: "29", Month: "02", Year: "2023"
[Expected] INVALID -> "Not a leap year"

TC04: Invalid month boundary [Type: BVA]
[Input] Day: "01", Month: "13", Year: "2023"
[Expected] INVALID -> "Month out of range"

TC05: Year below minimum [Type: BVA]
[Input] Day: "01", Month: "01", Year: "999"
[Expected] INVALID -> "Year below 1000"

TC06: Invalid day for month [Type: Error Guessing]
[Input] Day: "31", Month: "04", Year: "2023"
[Expected] INVALID -> "April only has 30 days"
