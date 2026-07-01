# Topic 5 - Performance Testing

This folder contains the files needed to demo performance/load testing for DateTimeChecker with k6.

## Files

- `run.bat`: double-click this file to start the demo.
- `run-performance.ps1`: implementation script called by `run.bat`.
- `load-test.js`: k6 load test script for `POST /api/datetime/check`.
- `test-data.json`: shared test cases used as random request payloads.
- `reports/`: created automatically; each run gets its own folder.

## What the demo does

1. Checks whether k6 and Java are available.
2. Checks whether the Spring Boot app is running at `http://localhost:18081`.
3. Starts the app with `mvnw.cmd spring-boot:run` if needed.
4. Waits until the app is ready.
5. Runs the k6 load test.
6. Saves the full output and results under `reports/run-YYYYMMDD-HHMMSS/`.

The demo uses port `18081` to avoid conflicts with other apps that may already use `8080`.
The default mode is `quick`, so the visible load test takes about 15 seconds and ramps gradually from 5 to 15 virtual users, then back to 0.

## Output files

Each run creates:

- `run.log`: full demo log and human-readable summary.
- `k6-console.log`: raw k6 console output.
- `k6-summary.json`: k6 JSON result summary.
- `spring-boot.log`: Spring Boot startup log, only when `run.bat` starts the app.

## Pass criteria

- 95% of requests finish under 500 ms.
- HTTP request failure rate is under 1%.
- More than 99% of checks pass.

## Demo speed

`run-performance.ps1` uses:

```powershell
$DemoMode = 'quick'
```

Change it to `full` if you want the longer 40-second run with up to 50 virtual users.
