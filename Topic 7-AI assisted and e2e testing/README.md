# Topic 7 - AI-assisted testing

This folder contains the Gemini-powered AI-assisted testing workflow for DateTimeChecker.

## Quick run

Double-click:

```bat
run.bat
```

The runner opens the AI-assisted testing prompt directly.

## One-time config

Create a local config file from the example:

```text
Topic 7-AI assisted and e2e testing\.env.local
```

Use this shape:

```text
GEMINI_API_KEY=your_api_key
GEMINI_MODEL=gemini-3.1-flash-lite
BASE_URL=http://localhost:18080
AI_TEST_STEP_DELAY_MS=900
AI_TEST_SELF_HEAL=1
```

`Topic 7-AI assisted and e2e testing\.env.local` is ignored by Git.

## Files

- `scripts/gemini-e2e-cli.js`: Gemini chat, test-case generation, AI-assisted approval flow, self-healing Playwright generation.
- `e2e/`: Gemini-generated Playwright specs.
- `docs/`: generated AI test-suite documents and CLI notes.
- `playwright-report/`: compact text/CSV summary report.
- `test-results/`: machine-readable JSON result file.

