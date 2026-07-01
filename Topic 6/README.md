# Topic 6 - Visual Regression Testing

Double-click `run.bat` to run visual regression testing.

What the runner does:

- Starts the Spring Boot app on a free local port.
- Installs npm dependencies and Playwright Chromium if they are missing.
- Creates baseline screenshots automatically on the first run.
- Captures current screenshots on every run.
- Compares the current UI against the baseline.

Image folders:

- `visual-artifacts/baseline`: before images used as the approved UI baseline.
- `visual-artifacts/current`: after images captured from the latest run.
- `visual-artifacts/diff`: actual/expected/diff images copied here when a visual mismatch happens.
- `visual-artifacts/reports`: run logs, Playwright report, traces, and raw test output.

To approve a new UI as the baseline, run:

```bat
run.bat update
```
