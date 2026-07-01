# Topic 3 - CI/CD with GitHub Actions

This folder contains the local demo files for triggering CI/CD on GitHub.

## Files

- `run.bat`: one-click runner that updates the demo note, commits current changes, pushes to GitHub, and triggers GitHub Actions.
- `DEMO_CI_NOTE.md`: timestamp note updated by `run.bat` so every demo can create a fresh commit.
- `CICD_REPORT.md`: report template and generated report format for completed GitHub Actions runs.

## How to Demo

1. Make sure the current branch is `hoangnhat-draft`.
2. Double-click `Topic 3-CICD\run.bat`.
3. Open GitHub Actions:
   https://github.com/nhatnhm1405/datetimechecker/actions
4. Open the completed run summary or download the `cicd-report` artifact.

The real workflow trigger file must stay at `.github/workflows/api-test.yml` because GitHub only detects workflow files from `.github/workflows`.

## What the Workflow Runs

- Unit tests with Maven.
- API tests with Newman/Postman collection.
- Desktop E2E tests with Playwright.
- Mobile tests with Playwright mobile emulation.
- k6 load test.
- Final CI/CD markdown report.
