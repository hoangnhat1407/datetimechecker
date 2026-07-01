# CI/CD Report - DateTimeChecker

This file is the report template used by GitHub Actions.

After a workflow run finishes, the `cicd-report` job generates a fresh report with:

- overall pipeline result;
- branch, commit, actor, run number, and run URL;
- result of each job: unit, API, E2E, mobile, and k6;
- links/instructions for GitHub Actions logs and artifacts.

The generated report is available in two places:

- GitHub Actions run summary.
- Artifact named `cicd-report`.

Run the demo with:

```bat
Topic 3-CICD\run.bat
```
