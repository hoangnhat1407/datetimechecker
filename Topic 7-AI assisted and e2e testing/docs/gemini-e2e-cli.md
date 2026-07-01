# Gemini AI-assisted testing CLI

This CLI powers Topic 7: AI-assisted testing with Gemini and Playwright.

## Quick start

Use:

```bat
Topic 7-AI assisted and e2e testing\run.bat
```

The batch file opens the AI-assisted testing prompt directly.

## Local config

Create `Topic 7-AI assisted and e2e testing\.env.local` from `Topic 7-AI assisted and e2e testing\.env.local.example`.

```text
GEMINI_API_KEY=your_api_key
GEMINI_MODEL=gemini-3.1-flash-lite
BASE_URL=http://localhost:18080
AI_TEST_STEP_DELAY_MS=900
AI_TEST_SELF_HEAL=1
```

`Topic 7-AI assisted and e2e testing\.env.local` is ignored by Git.

## Commands

```powershell
npm run ai-test
npm run gemini:chat
npm run gemini:e2e:generate
npm run gemini:e2e:run
npm run gemini:e2e
```

Direct script usage:

```powershell
node "Topic 7-AI assisted and e2e testing/scripts/gemini-e2e-cli.js" doctor
node "Topic 7-AI assisted and e2e testing/scripts/gemini-e2e-cli.js" generate --dry-run
```

## AI-assisted dashboard flow

1. Ask what you want Gemini to test in natural language.
2. Gemini proposes test cases.
3. Human approves the generated suite.
4. CLI asks whether to enable self-healing locator recovery.
5. CLI saves the approved suite to `Topic 7-AI assisted and e2e testing/docs/ai-generated-test-suite.md`.
6. CLI generates Playwright spec in `Topic 7-AI assisted and e2e testing/e2e/`.
7. CLI starts or reuses the local Spring Boot server.
8. Playwright opens Chromium and runs the approved E2E tests.
9. CLI writes compact reports to `Topic 7-AI assisted and e2e testing/playwright-report/`.

## Outputs

- `Topic 7-AI assisted and e2e testing/e2e/ai-assisted-generated.spec.js`
- `Topic 7-AI assisted and e2e testing/e2e/gemini-generated.spec.js`
- `Topic 7-AI assisted and e2e testing/docs/ai-generated-test-suite.md`
- `Topic 7-AI assisted and e2e testing/test-results/ai-assisted-results.json`
- `Topic 7-AI assisted and e2e testing/playwright-report/ai-assisted-summary.txt`
- `Topic 7-AI assisted and e2e testing/playwright-report/ai-assisted-summary.csv`

## Notes

- The CLI calls Gemini through REST; no separate Gemini SDK is required.
- Default model: `gemini-3.1-flash-lite`.
- If the primary model is busy, retryable errors can use fallback models.
- Do not commit API keys. Rotate the key if it was exposed.

