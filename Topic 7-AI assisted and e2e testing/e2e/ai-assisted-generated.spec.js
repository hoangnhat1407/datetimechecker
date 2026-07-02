// Generated from an approved AI-assisted test suite.
// Source command: npm run ai-test
// Model: gemini-3.1-flash-lite
// Generated at: 2026-07-02T01:14:05.299Z
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const VALID_COLOR = 'rgb(0, 128, 0)';
const INVALID_COLOR = 'rgb(255, 0, 0)';
const resultsPath = path.join(process.cwd(), 'Topic 7-AI assisted and e2e testing/test-results/ai-assisted-results.json');
const results = [];
const STEP_DELAY_MS = Number(process.env.AI_TEST_STEP_DELAY_MS || '900');
const SELF_HEAL_LOCATORS = !/^(0|false|no|off)$/i.test(String(process.env.AI_TEST_SELF_HEAL || '1'));
const STRICT_LOCATOR_TIMEOUT_MS = Number(process.env.AI_TEST_STRICT_LOCATOR_TIMEOUT_MS || '1200');
const HEAL_LOCATOR_TIMEOUT_MS = Number(process.env.AI_TEST_HEAL_LOCATOR_TIMEOUT_MS || '350');
const RESULT_LOCATOR_TIMEOUT_MS = Number(process.env.AI_TEST_RESULT_LOCATOR_TIMEOUT_MS || '3000');
const healEvents = [];

const testCases = [
  {
    "id": "TC01",
    "title": "Valid standard date",
    "testType": "EP",
    "day": "15",
    "month": "06",
    "year": "2023",
    "expectedStatus": "VALID"
  },
  {
    "id": "TC02",
    "title": "Leap year February 29th",
    "testType": "BVA",
    "day": "29",
    "month": "02",
    "year": "2024",
    "expectedStatus": "VALID"
  },
  {
    "id": "TC03",
    "title": "Non-leap year February 29th",
    "testType": "BVA",
    "day": "29",
    "month": "02",
    "year": "2023",
    "expectedStatus": "INVALID"
  },
  {
    "id": "TC04",
    "title": "Out of range year",
    "testType": "BVA",
    "day": "01",
    "month": "01",
    "year": "999",
    "expectedStatus": "INVALID"
  },
  {
    "id": "TC05",
    "title": "Invalid month value",
    "testType": "Error Guessing",
    "day": "10",
    "month": "13",
    "year": "2020",
    "expectedStatus": "INVALID"
  }
];

function expectedTextPattern(tc) {
  return tc.expectedStatus === 'VALID'
    ? /valid date/i
    : /(invalid date|must be|number|range|required|blank|empty)/i;
}

async function observeStep(page) {
  if (STEP_DELAY_MS > 0) {
    await page.waitForTimeout(STEP_DELAY_MS);
  }
}

function inputCandidates(page, field, label, index) {
  return [
    { name: '#' + field, locator: page.locator('#' + field) },
    { name: 'id contains ' + field, locator: page.locator('input[id*="' + field + '"]') },
    { name: 'css placeholder ' + label, locator: page.locator('input[placeholder="' + label + '"]') },
    { name: 'placeholder ' + label, locator: page.getByPlaceholder(new RegExp('^' + label + '$', 'i')) },
    { name: 'label ' + label, locator: page.getByLabel(new RegExp('^' + label + '$', 'i')) },
    { name: 'name=' + field, locator: page.locator('input[name="' + field + '"], input[name="' + label + '"]') },
    { name: 'aria-label ' + label, locator: page.locator('input[aria-label="' + label + '"], input[aria-label="' + field + '"]') },
    { name: 'input index ' + index, locator: page.locator('input').nth(index) },
  ];
}

function buttonCandidates(page) {
  return [
    { name: 'button text Check', locator: page.getByRole('button', { name: /check/i }) },
    { name: 'button text submit/validate', locator: page.getByRole('button', { name: /submit|validate|kiem tra/i }) },
    { name: 'button element', locator: page.locator('button').first() },
    { name: 'submit input', locator: page.locator('input[type="submit"], input[type="button"]').first() },
  ];
}

function resultCandidates(page) {
  return [
    { name: '#result', locator: page.locator('#result') },
    { name: 'result-like element', locator: page.locator('[id*="result"], [class*="result"], .fw-semibold').last() },
    { name: 'feedback paragraph', locator: page.locator('p, div, span').filter({ hasText: /valid date|invalid date|must be|number|range|required|blank|empty/i }).last() },
  ];
}

async function findVisibleCandidate(candidate, timeoutMs) {
  const locator = candidate.locator.first();
  if (await locator.count() === 0) return null;
  await locator.waitFor({ state: 'visible', timeout: timeoutMs });
  return locator;
}

function timeoutForPurpose(purpose, strictMode) {
  if (/result output/i.test(purpose)) return RESULT_LOCATOR_TIMEOUT_MS;
  return strictMode ? STRICT_LOCATOR_TIMEOUT_MS : HEAL_LOCATOR_TIMEOUT_MS;
}

async function healLocator(page, purpose, candidates) {
  const primary = candidates[0];
  if (!SELF_HEAL_LOCATORS) {
    try {
      const locator = await findVisibleCandidate(primary, timeoutForPurpose(purpose, true));
      if (locator) return locator;
    } catch {
      // Strict mode intentionally does not try fallback locators.
    }
    const fallbackNames = candidates.slice(1).map((candidate) => candidate.name).join(', ');
    throw new Error('[STRICT LOCATOR] ' + purpose + ' was not found with ' + primary.name + '. Enable AI Self-Healing Locator Recovery to try: ' + fallbackNames);
  }

  for (let index = 0; index < candidates.length; index += 1) {
    const candidate = candidates[index];
    try {
      const locator = await findVisibleCandidate(candidate, timeoutForPurpose(purpose, false));
      if (!locator) continue;
      if (index > 0) {
        healEvents.push({
          purpose,
          from: primary.name,
          to: candidate.name,
        });
      }
      return locator;
    } catch {
      // Try the next candidate locator.
    }
  }

  const tried = candidates.map((candidate) => candidate.name).join(', ');
  throw new Error('[SELF-HEAL FAILED] ' + purpose + ' was not found. Tried: ' + tried);
}

test.describe('AI-assisted DateTimeChecker E2E Suite', () => {
  test.afterAll(() => {
    fs.mkdirSync(path.dirname(resultsPath), { recursive: true });
    fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2), 'utf8');
  });

  for (const tc of testCases) {
    test(`${tc.id}: ${tc.title}`, async ({ page }) => {
      const summary = {
        id: tc.id,
        title: tc.title,
        testType: tc.testType,
        day: tc.day,
        month: tc.month,
        year: tc.year,
        expectedStatus: tc.expectedStatus,
      };
      const healStart = healEvents.length;

      try {
        await page.goto('/');
        await observeStep(page);
        const dayInput = await healLocator(page, 'day input', inputCandidates(page, 'day', 'Day', 0));
        await dayInput.fill(tc.day);
        await observeStep(page);
        const monthInput = await healLocator(page, 'month input', inputCandidates(page, 'month', 'Month', 1));
        await monthInput.fill(tc.month);
        await observeStep(page);
        const yearInput = await healLocator(page, 'year input', inputCandidates(page, 'year', 'Year', 2));
        await yearInput.fill(tc.year);
        await observeStep(page);
        const checkButton = await healLocator(page, 'check button', buttonCandidates(page));
        await checkButton.click();
        await observeStep(page);

        const result = await healLocator(page, 'result output', resultCandidates(page));
        await expect(result).toHaveCSS('color', tc.expectedStatus === 'VALID' ? VALID_COLOR : INVALID_COLOR);
        await expect(result).toContainText(expectedTextPattern(tc));
        const healedLocators = healEvents.slice(healStart);
        results.push({ ...summary, selfHealedLocators: healedLocators.length, healedLocators, result: 'SUCCEED' });
      } catch (error) {
        const healedLocators = healEvents.slice(healStart);
        results.push({ ...summary, selfHealedLocators: healedLocators.length, healedLocators, result: 'FAILED', error: error.message });
        throw error;
      }
    });
  }
});
