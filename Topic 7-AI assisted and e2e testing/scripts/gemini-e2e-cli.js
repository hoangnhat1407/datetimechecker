#!/usr/bin/env node

const fs = require('fs');
const os = require('os');
const path = require('path');
const readline = require('readline/promises');
const { spawn, spawnSync } = require('child_process');

const TOPIC_ROOT = path.resolve(__dirname, '..');
const ROOT = path.resolve(TOPIC_ROOT, '..');
const TOPIC_REL = path.relative(ROOT, TOPIC_ROOT).replace(/\\/g, '/');
const DEFAULT_MODEL = 'gemini-3.1-flash-lite';
const DEFAULT_FALLBACK_MODELS = ['gemini-2.5-flash-lite', 'gemini-2.5-flash', 'gemini-flash-latest'];
const DEFAULT_ASSISTED_STEP_DELAY_MS = 900;
const DEFAULT_SELF_HEAL_LOCATORS = true;
const DEFAULT_OUT = `${TOPIC_REL}/e2e/gemini-generated.spec.js`;
const ASSISTED_OUT = `${TOPIC_REL}/e2e/ai-assisted-generated.spec.js`;
const ASSISTED_JSON = `${TOPIC_REL}/test-results/ai-assisted-results.json`;
const ASSISTED_REPORT_TXT = `${TOPIC_REL}/playwright-report/ai-assisted-summary.txt`;
const ASSISTED_REPORT_CSV = `${TOPIC_REL}/playwright-report/ai-assisted-summary.csv`;
const AI_PLAYWRIGHT_CONFIG = `${TOPIC_REL}/playwright.ai.config.js`;
const GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta';

function usage() {
  console.log(`
Gemini E2E CLI

Commands:
  doctor     Check Gemini connectivity and configuration
  chat       Start an interactive Gemini testing chat
  assist     Start an AI-assisted test-suite proposal flow
  generate   Call Gemini API and write a Playwright spec
  run        Run the generated Playwright spec
  all        Generate, then run the generated Playwright spec

Environment:
  GEMINI_API_KEY   Required for assist/generate/all
  GEMINI_MODEL     Optional, default: ${DEFAULT_MODEL}
  GEMINI_FALLBACK_MODELS
                   Optional comma-separated fallback models
  BASE_URL         Optional, default: http://localhost:8080
  AI_TEST_STEP_DELAY_MS
                   Optional delay between visible E2E steps, default: ${DEFAULT_ASSISTED_STEP_DELAY_MS}
  AI_TEST_SELF_HEAL
                   Optional locator self-healing toggle, default: 1

Examples:
  $env:GEMINI_API_KEY="your-key"
  $env:AI_TEST_STEP_DELAY_MS="1500"
  $env:AI_TEST_SELF_HEAL="1"
  ${TOPIC_REL}\\run.bat
  npm run ai-test
  npm run gemini:chat
  npm run gemini:e2e
`);
}

function parseArgs(argv) {
  const opts = {
    command: argv[2] || 'help',
    model: process.env.GEMINI_MODEL || DEFAULT_MODEL,
    out: DEFAULT_OUT,
    baseUrl: process.env.BASE_URL || 'http://localhost:8080',
    stepDelayMs: parseInteger(process.env.AI_TEST_STEP_DELAY_MS, DEFAULT_ASSISTED_STEP_DELAY_MS),
    selfHeal: parseBoolean(process.env.AI_TEST_SELF_HEAL, DEFAULT_SELF_HEAL_LOCATORS),
    dryRun: false,
    headed: false,
  };

  for (const arg of argv.slice(3)) {
    if (arg === '--dry-run') opts.dryRun = true;
    else if (arg.startsWith('--model=')) opts.model = arg.slice('--model='.length);
    else if (arg.startsWith('--out=')) opts.out = arg.slice('--out='.length);
    else if (arg.startsWith('--base-url=')) opts.baseUrl = arg.slice('--base-url='.length);
    else if (arg.startsWith('--step-delay=')) opts.stepDelayMs = parseInteger(arg.slice('--step-delay='.length), DEFAULT_ASSISTED_STEP_DELAY_MS);
    else if (arg === '--self-heal') opts.selfHeal = true;
    else if (arg === '--no-self-heal') opts.selfHeal = false;
    else if (arg === '--headed') opts.headed = true;
    else if (arg === '--help' || arg === '-h') opts.command = 'help';
    else throw new Error(`Unknown argument: ${arg}`);
  }

  return opts;
}

function parseInteger(value, fallback) {
  if (value === undefined || value === null || value === '') return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

function parseBoolean(value, fallback) {
  if (value === undefined || value === null || value === '') return fallback;
  return !/^(0|false|no|off)$/i.test(String(value).trim());
}

function geminiEndpoint(model) {
  const normalizedModel = model.replace(/^models\//, '');
  return `${GEMINI_API_BASE}/models/${encodeURIComponent(normalizedModel)}:generateContent`;
}

function modelPlan(primaryModel) {
  const hasFallbackOverride = Object.prototype.hasOwnProperty.call(process.env, 'GEMINI_FALLBACK_MODELS');
  const fallbackRaw = process.env.GEMINI_FALLBACK_MODELS;
  const fallbacks = fallbackRaw
    ? fallbackRaw.split(',').map((item) => item.trim()).filter(Boolean)
    : (hasFallbackOverride ? [] : DEFAULT_FALLBACK_MODELS);

  return [...new Set([primaryModel, ...fallbacks])];
}

function readText(relativePath) {
  return fs.readFileSync(path.join(ROOT, relativePath), 'utf8');
}

function buildPrompt() {
  const testData = readText('test-data.json');
  const html = readText('src/main/resources/static/index.html');
  const existingSpec = readText('e2e/test.spec.js');
  const config = readText('playwright.config.js');

  return `
You are generating Playwright E2E tests for a Spring Boot app named DateTimeChecker.

Goal:
- Generate one complete CommonJS Playwright spec file.
- The generated file must test the desktop web UI at "/".
- It must create AI-assisted test cases from the business rules and the shared test-data.json.
- Keep tests deterministic and fast.

API contract:
- POST /api/datetime/check
- Request JSON: { "day": string, "month": string, "year": string }
- Response JSON: { "valid": boolean, "message": string, "field": string | null }
- Invalid business input still returns HTTP 200.

UI contract:
- Page URL is "/".
- Inputs: #day, #month, #year
- Button text is "Check"; there is one button on the page.
- Result element: #result
- Result color is green for valid and red for invalid.

Existing Playwright config:
\`\`\`js
${config}
\`\`\`

Existing human-written E2E style:
\`\`\`js
${existingSpec}
\`\`\`

Current static HTML:
\`\`\`html
${html}
\`\`\`

Shared test data:
\`\`\`json
${testData}
\`\`\`

Output rules:
- Return only JSON. No markdown.
- JSON shape: { "code": "..." }
- The code must use: const { test, expect } = require('@playwright/test');
- The code must not import any local helper unless you define the fallback correctly.
- The code should include 8 to 12 representative AI-generated test cases.
- Cover valid boundaries, invalid field validation, leap-year logic, and visible UI feedback.
- Prefer checking result text plus CSS color.
- Do not call external services from the Playwright tests.
`;
}

function buildPromptFromApprovedSuite(request, approvedSuite) {
  const html = readText('src/main/resources/static/index.html');
  const existingSpec = readText('e2e/test.spec.js');
  const config = readText('playwright.config.js');

  return `
You are converting a human-approved AI test suite into one executable Playwright E2E spec.

Natural-language testing request:
${request}

Human-approved suite:
\`\`\`text
${approvedSuite}
\`\`\`

Target app:
- Spring Boot DateTimeChecker UI at "/".
- Inputs: #day, #month, #year
- One Check button.
- Result element: #result
- Result color is green for valid and red for invalid.
- API/business rule invalid input still renders a red invalid/error result in UI.
- Actual app messages are generated by DateTimeCheckerService and may differ from the natural-language reason in the approved suite.
- Valid result examples look like "15/05/2023 is a valid date.".
- Invalid date result examples look like "29/02/2100 is an invalid date.".
- Field validation examples include "Year must be in range 1000 to 3000." and "Month must be in range 1 to 12.".

Existing Playwright config:
\`\`\`js
${config}
\`\`\`

Existing human-written E2E style:
\`\`\`js
${existingSpec}
\`\`\`

Current static HTML:
\`\`\`html
${html}
\`\`\`

Output rules:
- Return only JSON. No markdown.
- JSON shape: { "code": "..." }
- The code must use: const { test, expect } = require('@playwright/test');
- The code must be CommonJS.
- The code must execute the approved test cases from the suite above.
- Use page.goto('/'), fill #day/#month/#year, click the Check button, then assert #result.
- Do not assert exact text from the approved suite's reason. That reason is human-readable, not the app's exact UI message.
- Determine each case's expected status from [Expected] VALID or [Expected] INVALID/ERROR in the approved suite.
- Assert green color for VALID and red color for INVALID/ERROR.
- For VALID, assert result text contains "valid date".
- For INVALID/ERROR, assert result text contains one of: "invalid date", "must be", "number", "range".
- Add a JSON reporter helper in the generated spec:
  const fs = require('fs');
  const path = require('path');
  const resultsPath = path.join(process.cwd(), 'test-results', 'ai-assisted-results.json');
  const results = [];
  test.afterAll(() => { fs.mkdirSync(path.dirname(resultsPath), { recursive: true }); fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2)); });
- Add a visible step delay helper:
  const STEP_DELAY_MS = Number(process.env.AI_TEST_STEP_DELAY_MS || '${DEFAULT_ASSISTED_STEP_DELAY_MS}');
  async function observeStep(page) { if (STEP_DELAY_MS > 0) await page.waitForTimeout(STEP_DELAY_MS); }
- Call observeStep(page) after page.goto('/'), after each fill, and after clicking Check so humans can watch the browser.
- Add self-healing locator helpers. Primary locators are #day, #month, #year, the Check button, and #result. If a primary locator fails, try fallback locators by placeholder, label, role, name, text, and input index.
- Track healed locator events and include selfHealedLocators plus healedLocators in each result object.
- In each test, push { id, title, testType, day, month, year, expectedStatus: "VALID" or "INVALID", selfHealedLocators, healedLocators, result: "SUCCEED" } after assertions pass.
- If an assertion fails, catch the error, push { id, title, testType, day, month, year, expectedStatus, selfHealedLocators, healedLocators, result: "FAILED", error: error.message }, then rethrow.
- Keep tests deterministic and independent.
- Do not call Gemini or any external service from the Playwright tests.
`;
}

async function callGemini(prompt, opts) {
  let lastError;
  for (const model of modelPlan(opts.model)) {
    try {
      if (model !== opts.model) {
        console.log(`Retrying with fallback model ${model}...`);
      }
      return await callGeminiModel(prompt, { ...opts, model });
    } catch (err) {
      lastError = err;
      if (!isRetryableGeminiError(err)) {
        throw err;
      }
      console.warn(err.message);
      console.warn(`Model ${model} is temporarily unavailable. Trying next option...`);
    }
  }
  throw lastError;
}

async function callGeminiModel(prompt, opts) {
  const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
  if (!apiKey) {
    throw new Error(
      'Missing GEMINI_API_KEY. Create a key in Google AI Studio, then set $env:GEMINI_API_KEY="your-key".'
    );
  }

  const requestBody = JSON.stringify({
    systemInstruction: {
      parts: [
        {
          text: opts.systemPrompt || 'You are a senior QA automation engineer. Return only machine-parseable JSON.',
        },
      ],
    },
    contents: [
      {
        role: 'user',
        parts: [{ text: prompt }],
      },
    ],
    generationConfig: buildGenerationConfig(opts),
  });
  const endpoint = geminiEndpoint(opts.model);

  let res;
  try {
    res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: requestBody,
    });
  } catch (err) {
    console.warn(formatFetchError(err));
    console.warn('Retrying Gemini request with curl...');
    return callGeminiWithCurl(endpoint, apiKey, requestBody);
  }

  const bodyText = await res.text();
  let body;
  try {
    body = JSON.parse(bodyText);
  } catch {
    body = { raw: bodyText };
  }

  if (!res.ok) {
    const err = new Error(`Gemini API failed (${res.status}) on ${opts.model}: ${JSON.stringify(body, null, 2)}`);
    err.status = res.status;
    err.body = body;
    throw err;
  }

  return extractText(body);
}

function buildGenerationConfig(opts) {
  const config = {
    temperature: opts.temperature ?? 0.2,
  };

  if (opts.responseMimeType) {
    config.responseMimeType = opts.responseMimeType;
  }

  return config;
}

function isRetryableGeminiError(err) {
  return err && (err.status === 429 || err.status === 500 || err.status === 502 || err.status === 503 || err.status === 504);
}

function callGeminiWithCurl(endpoint, apiKey, requestBody) {
  const curl = process.platform === 'win32' ? 'curl.exe' : 'curl';
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'gemini-e2e-'));
  const requestPath = path.join(tmpDir, 'request.json');
  const responsePath = path.join(tmpDir, 'response.json');
  const configPath = path.join(tmpDir, 'curl.conf');

  try {
    fs.writeFileSync(requestPath, requestBody, 'utf8');
    fs.writeFileSync(configPath, [
      `url = "${escapeCurlConfig(endpoint)}"`,
      'request = "POST"',
      'silent',
      'show-error',
      `header = "Content-Type: application/json"`,
      `header = "x-goog-api-key: ${escapeCurlConfig(apiKey)}"`,
      `data-binary = "@${escapeCurlConfig(requestPath)}"`,
      `output = "${escapeCurlConfig(responsePath)}"`,
      'write-out = "%{http_code}"',
      '',
    ].join('\n'), 'utf8');

    const result = spawnSync(curl, ['--config', configPath], {
      cwd: ROOT,
      encoding: 'utf8',
    });

    if (result.error) {
      throw new Error(`curl fallback failed: ${result.error.message}`);
    }

    const status = Number((result.stdout || '').trim());
    const stderr = (result.stderr || '').trim();
    const bodyText = fs.existsSync(responsePath) ? fs.readFileSync(responsePath, 'utf8') : '';
    let body;
    try {
      body = JSON.parse(bodyText);
    } catch {
      body = { raw: bodyText };
    }

    if (!status || status < 200 || status >= 300) {
      const err = new Error(`Gemini API failed via curl (${status || 'no status'}): ${stderr || JSON.stringify(body, null, 2)}`);
      err.status = status;
      err.body = body;
      throw err;
    }

    return extractText(body);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

function escapeCurlConfig(value) {
  return String(value).replace(/\\/g, '/').replace(/"/g, '\\"');
}

function formatFetchError(err) {
  const details = [
    'Gemini request failed before receiving an HTTP response.',
    `Node error: ${err.message}`,
  ];

  if (err.cause) {
    if (err.cause.code) details.push(`Cause code: ${err.cause.code}`);
    if (err.cause.message) details.push(`Cause message: ${err.cause.message}`);
    if (err.cause.hostname) details.push(`Hostname: ${err.cause.hostname}`);
    if (err.cause.address) details.push(`Address: ${err.cause.address}`);
    if (err.cause.port) details.push(`Port: ${err.cause.port}`);
  }

  details.push(`Try: node "${TOPIC_REL}/scripts/gemini-e2e-cli.js" doctor`);
  details.push('If curl works but Node fetch fails, check proxy/TLS settings for Node.js.');
  return details.join('\n');
}

async function doctor(opts) {
  console.log(`Model: ${opts.model}`);
  console.log(`Endpoint: ${geminiEndpoint(opts.model)}`);
  console.log(`GEMINI_API_KEY: ${(process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY) ? 'present' : 'missing'}`);
  console.log(`HTTPS_PROXY: ${process.env.HTTPS_PROXY || process.env.https_proxy || '(not set)'}`);
  console.log(`HTTP_PROXY: ${process.env.HTTP_PROXY || process.env.http_proxy || '(not set)'}`);
  console.log(`NODE_EXTRA_CA_CERTS: ${process.env.NODE_EXTRA_CA_CERTS || '(not set)'}`);

  try {
    const res = await fetch('https://generativelanguage.googleapis.com', { method: 'HEAD' });
    console.log(`Node fetch connectivity: HTTP ${res.status}`);
  } catch (err) {
    console.log('Node fetch connectivity: FAILED');
    console.log(formatFetchError(err));
  }

  const curl = process.platform === 'win32' ? 'curl.exe' : 'curl';
  const curlResult = spawnSync(curl, ['-I', '-s', 'https://generativelanguage.googleapis.com'], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  if (curlResult.error) {
    console.log(`curl connectivity: FAILED (${curlResult.error.message})`);
  } else {
    const firstLine = (curlResult.stdout || curlResult.stderr || '').split(/\r?\n/).find(Boolean);
    console.log(`curl connectivity: ${firstLine || `exit ${curlResult.status}`}`);
  }

  if (process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY) {
    try {
      const text = await callGemini('Reply with exactly: OK', opts);
      console.log(`Gemini API probe: ${text.trim() || '(empty response)'}`);
    } catch (err) {
      console.log('Gemini API probe: FAILED');
      console.log(err.message);
    }
  } else {
    console.log('Gemini API probe: skipped because GEMINI_API_KEY is missing');
  }
}

function chatSystemPrompt() {
  return `
You are Gemini running as a normal interactive AI chatbot in a developer's CLI.
Answer naturally and helpfully.
You can discuss general topics, explain code, brainstorm, write text, and help with programming.
Keep answers concise by default, but provide enough detail when the user asks for it.
`;
}

function dateTimeCheckerContext() {
  return `
DateTimeChecker project context:
- Spring Boot REST API validates day/month/year strings using Gregorian calendar rules.
- Endpoint: POST /api/datetime/check.
- Request JSON: { "day": string, "month": string, "year": string }.
- Response JSON: { "valid": boolean, "message": string, "field": string | null }.
- Invalid business input returns HTTP 200 with valid=false.
- Rules: day must be integer 1..31, month must be integer 1..12, year must be integer 1000..3000.
- Gregorian leap year: divisible by 400 is leap, divisible by 100 but not 400 is not leap, otherwise divisible by 4 is leap.
- Existing tooling: JUnit 5, Postman/Newman, Playwright, k6, Docker, GitHub Actions.
`;
}

function testCasesPrompt(extra) {
  const suffix = extra ? `\nExtra requirement from user: ${extra}` : '';
  return `${dateTimeCheckerContext()}

Create a compact but complete set of DateTimeChecker test cases.
Cover:
- valid lower/upper date boundaries,
- month length rules,
- leap-year and non-leap-year traps,
- invalid day/month/year ranges,
- non-numeric, blank, decimal, and special-character input,
- expectedValid and expectedField.
Return a Markdown table and a short note about which test layer should use these cases.${suffix}
`;
}

function formatChatPrompt(history, userMessage) {
  const recent = history.slice(-8).map((item) => {
    const role = item.role === 'user' ? 'User' : 'Gemini';
    return `${role}: ${item.text}`;
  }).join('\n\n');

  return recent
    ? `${recent}\n\nUser: ${userMessage}\n\nGemini:`
    : userMessage;
}

async function chat(opts) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const history = [];
  let lastReply = '';
  let projectContextEnabled = false;

  console.log(`Gemini chat started with model ${opts.model}.`);
  console.log('Commands: /testcases [notes], /context on|off, /save [path], /clear, /help, /exit');

  try {
    while (true) {
      const raw = await rl.question('\nYou> ');
      const input = raw.trim();

      if (!input) continue;
      if (input === '/exit' || input === '/quit') break;

      if (input === '/help') {
        console.log([
          'Commands:',
          '  /testcases [notes]  Ask Gemini to create DateTimeChecker test cases',
          '  /context on|off     Toggle DateTimeChecker project context for normal chat',
          `  /save [path]        Save the last Gemini reply, default ${TOPIC_REL}/docs/gemini-chat-output.md`,
          '  /clear              Clear local chat memory',
          '  /exit               End chat',
          '',
          'Type normally to chat with Gemini like a regular chatbot.',
        ].join('\n'));
        continue;
      }

      if (input.startsWith('/context')) {
        const value = input.slice('/context'.length).trim().toLowerCase();
        if (value === 'on') {
          projectContextEnabled = true;
        } else if (value === 'off') {
          projectContextEnabled = false;
        } else {
          console.log(`Project context is ${projectContextEnabled ? 'on' : 'off'}. Use /context on or /context off.`);
          continue;
        }
        console.log(`Project context ${projectContextEnabled ? 'enabled' : 'disabled'}.`);
        continue;
      }

      if (input === '/clear') {
        history.length = 0;
        lastReply = '';
        console.log('Chat memory cleared.');
        continue;
      }

      if (input.startsWith('/save')) {
        const requestedPath = input.slice('/save'.length).trim() || `${TOPIC_REL}/docs/gemini-chat-output.md`;
        if (!lastReply) {
          console.log('Nothing to save yet.');
          continue;
        }
        const outputPath = resolveWorkspacePath(requestedPath);
        fs.mkdirSync(path.dirname(outputPath), { recursive: true });
        fs.writeFileSync(outputPath, lastReply + '\n', 'utf8');
        console.log(`Saved ${path.relative(ROOT, outputPath)}`);
        continue;
      }

      const isTestCaseRequest = input.startsWith('/testcases');
      const message = isTestCaseRequest
        ? testCasesPrompt(input.slice('/testcases'.length).trim())
        : (projectContextEnabled ? `${dateTimeCheckerContext()}\n\nUser question: ${input}` : input);

      const prompt = formatChatPrompt(history, message);
      history.push({ role: 'user', text: message });

      try {
        const reply = await callGemini(prompt, {
          ...opts,
          systemPrompt: chatSystemPrompt(),
          responseMimeType: null,
          temperature: 0.3,
        });
        lastReply = reply.trim();
        history.push({ role: 'assistant', text: lastReply });
        console.log(`\nGemini>\n${lastReply}`);
      } catch (err) {
        history.pop();
        console.log(`\nGemini error: ${err.message}`);
      }
    }
  } finally {
    rl.close();
  }
}

function resolveWorkspacePath(userPath) {
  const outputPath = path.resolve(ROOT, userPath);
  const relative = path.relative(ROOT, outputPath);
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`Refusing to write outside the project: ${userPath}`);
  }
  return outputPath;
}

const ansi = {
  reset: '\x1b[0m',
  cyan: '\x1b[36m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  magenta: '\x1b[35m',
  red: '\x1b[31m',
  dim: '\x1b[2m',
};

function color(text, name) {
  return `${ansi[name] || ''}${text}${ansi.reset}`;
}

function assistantSystemPrompt() {
  return `
You are an AI-assisted testing assistant running in a CLI.
Your job is to propose practical test suites from a natural-language testing request.
When the project is DateTimeChecker, use this context:
- It validates Day/Month/Year strings according to Gregorian calendar rules.
- Endpoint: POST /api/datetime/check.
- Request JSON: { "day": string, "month": string, "year": string }.
- Response JSON: { "valid": boolean, "message": string, "field": string | null }.
- Invalid business input still returns HTTP 200 with valid=false.
- Day must be integer 1..31. Month must be integer 1..12. Year must be integer 1000..3000.
- Leap-year rule: divisible by 400 is leap; divisible by 100 but not 400 is not leap; otherwise divisible by 4 is leap.

Return only the proposed suite text, no greeting.
Use this style:
- TC01: Short title [Type: BVA/EP/Error Guessing/Regression]
  [Input] Day: "...", Month: "...", Year: "..."
  [Expected] VALID/INVALID/ERROR -> "short expected result"

If the user asks for a number of cases, generate exactly that number.
Otherwise generate 5 cases.
Keep the suite concise and easy to review in a terminal.
`;
}

function buildAssistantPrompt(request) {
  return `
Testing request:
${request}

Generate the test suite proposal now.
`;
}

async function requestAssistantSuite(rl, request, opts) {
  while (true) {
    try {
      return (await callGemini(buildAssistantPrompt(request), {
        ...opts,
        systemPrompt: assistantSystemPrompt(),
        responseMimeType: null,
        temperature: 0.25,
      })).trim();
    } catch (err) {
      if (!isInvalidApiKeyError(err)) throw err;
      const recovered = await askForReplacementGeminiKey(rl);
      if (!recovered) throw err;
      console.log(color('[AI CONFIG] Retrying Gemini request with the new API key...', 'cyan'));
    }
  }
}

function isInvalidApiKeyError(err) {
  const details = `${err && err.message ? err.message : ''} ${JSON.stringify((err && err.body) || {})}`;
  return /API_KEY_INVALID|API key not valid|INVALID_ARGUMENT/i.test(details);
}

async function askForReplacementGeminiKey(rl) {
  console.log(color('[AI CONFIG] The saved GEMINI_API_KEY is invalid or expired.', 'red'));
  console.log(color('[AI CONFIG] Please create/copy a valid key from Google AI Studio, then paste it below.', 'yellow'));
  const key = (await rl.question(color('Paste new GEMINI_API_KEY (or press Enter to cancel): ', 'magenta'))).trim();
  if (!key) return false;

  process.env.GEMINI_API_KEY = key;
  const defaultSave = 'Y';
  const save = await rl.question(color(`Save this key to ${TOPIC_REL}/.env.local? (Y/N) [Default: ${defaultSave}]: `, 'magenta'));
  if (!save.trim() || save.trim().toLowerCase().startsWith('y')) {
    upsertTopicEnvValue('GEMINI_API_KEY', key);
    console.log(color(`[AI CONFIG] Updated ${TOPIC_REL}/.env.local.`, 'green'));
  } else {
    console.log(color('[AI CONFIG] New key will be used for this run only.', 'yellow'));
  }
  return true;
}

function upsertTopicEnvValue(key, value) {
  const envPath = path.join(TOPIC_ROOT, '.env.local');
  const lines = fs.existsSync(envPath)
    ? fs.readFileSync(envPath, 'utf8').split(/\r?\n/).filter((line) => line.length > 0)
    : [];
  let found = false;
  const nextLines = lines.map((line) => {
    if (line.startsWith(`${key}=`)) {
      found = true;
      return `${key}=${value}`;
    }
    return line;
  });
  if (!found) nextLines.push(`${key}=${value}`);
  fs.writeFileSync(envPath, `${nextLines.join(os.EOL)}${os.EOL}`, 'utf8');
}

async function assist(opts) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const keyPresent = Boolean(process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY);
  const defaultRequest = 'generate 5 test cases to test DateTimeChecker';
  let lastSuite = '';

  console.log(color('============================================================', 'cyan'));
  console.log(color('      AI-ASSISTED TESTING ASSISTANT DASHBOARD (SWT301)', 'cyan'));
  console.log(color('============================================================', 'cyan'));
  console.log('');

  if (keyPresent) {
    console.log(color('[AI CONFIG] Found GEMINI_API_KEY in environment. Using live AI model.', 'green'));
  } else {
    console.log(color('[AI CONFIG] GEMINI_API_KEY is missing. Set it before using live AI mode.', 'red'));
  }

  console.log('');
  console.log(color('Describe what you want the AI to test in natural language.', 'yellow'));
  console.log(color('Examples:', 'yellow'));
  console.log('  - "generate 5 test cases for leap years"');
  console.log('  - "test boundary values for day and month"');
  console.log('  - "test incorrect input format error handling"');
  console.log('');

  try {
    while (true) {
      const raw = await rl.question(color('Enter your testing request (or press Enter for default suite): ', 'magenta'));
      const request = raw.trim() || defaultRequest;
      console.log(color(`[AI CONFIG] Testing request: "${request}"`, 'green'));
      console.log('');
      console.log(color('[STEP 1] AI analyzing requirements and generating test suite...', 'yellow'));
      console.log(color(`[Gemini API] Querying ${opts.model} for test design proposal...`, 'cyan'));
      console.log('');

      try {
        lastSuite = await requestAssistantSuite(rl, request, opts);
      } catch (err) {
        console.log(color(`Gemini error: ${err.message}`, 'red'));
        const retry = await rl.question(color('Try another request? (Y/N): ', 'magenta'));
        if (!retry.trim().toLowerCase().startsWith('y')) break;
        continue;
      }

      console.log(color('[AI GENERATION COMPLETE] Live Gemini Model proposed the following Test Suite:', 'green'));
      console.log('------------------------------------------------------------');
      console.log(lastSuite);
      console.log('------------------------------------------------------------');
      console.log('');
      console.log(color('>>> HUMAN-IN-THE-LOOP CONTROL REQUIRED <<<', 'red'));
      console.log('AI can suggest test designs, but humans must sign off to prevent false assumptions.');

      const approval = await rl.question(color('Do you approve the AI-generated test suite? (Y/N): ', 'magenta'));
      if (approval.trim().toLowerCase().startsWith('y')) {
        await executeApprovedSuite(request, lastSuite, opts, rl);
        break;
      }

      const revise = await rl.question(color('Enter revision notes, or press Enter to cancel: ', 'magenta'));
      if (!revise.trim()) {
        console.log('Cancelled without saving.');
        break;
      }
      console.log('');
      const revisedPrompt = `${request}. Revision notes: ${revise.trim()}`;
      console.log(color(`[AI CONFIG] Revision request: "${revisedPrompt}"`, 'green'));
      console.log('');
      lastSuite = await requestAssistantSuite(rl, revisedPrompt, opts);
      console.log(color('[AI GENERATION COMPLETE] Revised Test Suite:', 'green'));
      console.log('------------------------------------------------------------');
      console.log(lastSuite);
      console.log('------------------------------------------------------------');
      const approveRevision = await rl.question(color('Do you approve the revised suite? (Y/N): ', 'magenta'));
      if (approveRevision.trim().toLowerCase().startsWith('y')) {
        await executeApprovedSuite(revisedPrompt, lastSuite, opts, rl);
        break;
      }
      console.log('Cancelled without saving.');
      break;
    }
  } finally {
    rl.close();
  }
}

async function askSelfHealingPreference(rl, opts) {
  const defaultAnswer = opts.selfHeal ? 'Y' : 'N';
  console.log('');
  console.log(color('[AI CONFIG] AI Self-Healing helps recover broken Locators (e.g. changed submit buttons) visually.', 'yellow'));
  const answer = await rl.question(color(`Enable AI Self-Healing Locator Recovery? (Y/N) [Default: ${defaultAnswer}]: `, 'magenta'));
  const normalized = answer.trim().toLowerCase();
  const selfHeal = normalized ? normalized.startsWith('y') : opts.selfHeal;
  console.log(color(`[AI CONFIG] Self-Healing Locator Recovery ${selfHeal ? 'enabled' : 'disabled'}.`, selfHeal ? 'green' : 'yellow'));
  return {
    ...opts,
    selfHeal,
  };
}

async function executeApprovedSuite(request, suite, opts, rl = null) {
  const outputPath = resolveWorkspacePath(`${TOPIC_REL}/docs/ai-generated-test-suite.md`);
  const content = [
    '# AI-generated test suite',
    '',
    `Request: ${request}`,
    `Model: ${opts.model}`,
    `Generated at: ${new Date().toISOString()}`,
    '',
    suite,
    '',
  ].join('\n');
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, content, 'utf8');
  console.log(color(`[APPROVED] Saved ${path.relative(ROOT, outputPath)}`, 'green'));
  console.log(color('[APPROVED] Test suite approved. Proceeding to execution...', 'green'));

  const executionOpts = rl ? await askSelfHealingPreference(rl, opts) : opts;
  const specOut = await generateSpecFromSuite(request, suite, executionOpts);
  let serverProcess = null;
  try {
    serverProcess = await ensureServer(executionOpts.baseUrl);
    console.log(color('[STEP 3] Running Playwright E2E tests. Chromium will open if headed mode is available...', 'yellow'));
    console.log(color(`[E2E SPEED] Step delay: ${executionOpts.stepDelayMs}ms. Set AI_TEST_STEP_DELAY_MS=0 to run fast.`, 'yellow'));
    console.log(color(`[SELF-HEALING] Locator recovery: ${executionOpts.selfHeal ? 'enabled' : 'disabled'}. Set AI_TEST_SELF_HEAL=0 to disable.`, executionOpts.selfHeal ? 'green' : 'yellow'));
    fs.rmSync(path.join(ROOT, ASSISTED_JSON), { force: true });
    const result = run({
      ...executionOpts,
      out: specOut,
      headed: true,
      exitOnFailure: false,
      quiet: true,
    });
    const printedSummary = printAssistedSummary();
    if (result.status !== 0) {
      if (!printedSummary && (result.stdout || result.stderr)) {
        console.log((result.stdout || result.stderr).trim());
      }
      throw new Error(`Playwright exited with status ${result.status}`);
    }
    console.log(color('[E2E COMPLETE] Approved AI-assisted tests finished successfully.', 'green'));
  } finally {
    if (serverProcess && !serverProcess.killed) {
      serverProcess.kill();
      console.log(color('[SERVER] Stopped local server started by ai-test.', 'dim'));
    }
  }
}

function printAssistedSummary() {
  const resultsPath = path.join(ROOT, ASSISTED_JSON);
  if (!fs.existsSync(resultsPath)) {
    console.log(color('[AI TEST SUMMARY] No compact result file was produced.', 'yellow'));
    return false;
  }

  const results = JSON.parse(fs.readFileSync(resultsPath, 'utf8'));
  const reportTextPath = path.join(ROOT, ASSISTED_REPORT_TXT);
  const reportCsvPath = path.join(ROOT, ASSISTED_REPORT_CSV);
  const lines = renderAssistedSummary(results, true);
  const plainLines = renderAssistedSummary(results, false);

  console.log('');
  console.log(lines.join('\n'));

  fs.mkdirSync(path.dirname(reportTextPath), { recursive: true });
  fs.writeFileSync(reportTextPath, plainLines.join('\n') + '\n', 'utf8');
  fs.writeFileSync(reportCsvPath, toAssistedCsv(results), 'utf8');
  console.log(color(`[REPORT] Text: ${path.relative(ROOT, reportTextPath)}`, 'green'));
  console.log(color(`[REPORT] CSV : ${path.relative(ROOT, reportCsvPath)}`, 'green'));
  return true;
}

function renderAssistedSummary(results, colorize) {
  const widths = {
    id: 5,
    title: 27,
    type: 24,
    input: 23,
    expected: 8,
    status: 8,
  };
  const totalWidth = Object.values(widths).reduce((sum, width) => sum + width, 0) + 15;
  const divider = '-'.repeat(totalWidth);
  const rows = [];
  let succeed = 0;
  let failed = 0;
  let selfHealedLocators = 0;

  rows.push(colorize ? color('[AI TEST SUMMARY]', 'cyan') : '[AI TEST SUMMARY]');
  rows.push(divider);
  rows.push([
    fitCell('ID', widths.id),
    fitCell('Test Case Name', widths.title),
    fitCell('Test Type', widths.type),
    fitCell('Inputs', widths.input),
    fitCell('Expected', widths.expected),
    fitCell('Status', widths.status),
  ].join(' | '));
  rows.push(divider);

  for (const item of results) {
    const passed = item.result === 'SUCCEED';
    if (passed) succeed += 1;
    else failed += 1;
    selfHealedLocators += Number(item.selfHealedLocators || 0);

    const expected = item.expectedStatus === 'VALID' ? 'VALID' : 'INVALID';
    const statusText = passed ? 'SUCCEED' : 'FAILED';
    const statusCell = colorize
      ? color(fitCell(statusText, widths.status), passed ? 'green' : 'red')
      : fitCell(statusText, widths.status);

    rows.push([
      fitCell(item.id || 'TC??', widths.id),
      fitCell(item.title || 'Untitled', widths.title),
      fitCell(item.testType || inferTestType(item.title), widths.type),
      fitCell(formatCaseInput(item), widths.input),
      fitCell(expected, widths.expected),
      statusCell,
    ].join(' | '));
  }

  rows.push(divider);
  rows.push(`Total Tests: ${results.length} | Passed: ${succeed} | Failed: ${failed}`);
  rows.push(`Self-Healed Locators: ${selfHealedLocators}`);
  rows.push(colorize
    ? color(`Overall: ${failed === 0 ? 'SUCCEED' : 'FAILED'}`, failed === 0 ? 'green' : 'red')
    : `Overall: ${failed === 0 ? 'SUCCEED' : 'FAILED'}`);
  return rows;
}

function fitCell(value, width) {
  const text = String(value ?? '').replace(/\s+/g, ' ').trim();
  if (text.length <= width) return text.padEnd(width);
  return `${text.slice(0, Math.max(0, width - 3))}...`;
}

function formatCaseInput(item) {
  if (item.input) return item.input;
  const day = item.day ?? '?';
  const month = item.month ?? '?';
  const year = item.year ?? '?';
  return `D:${day}, M:${month}, Y:${year}`;
}

function inferTestType(title = '') {
  if (/boundary|lower|upper|min|max|range/i.test(title)) return 'Boundary Value';
  if (/invalid|incorrect|format|non|blank|empty|special|decimal|error/i.test(title)) return 'Error Guessing';
  if (/leap|month|standard|valid|calendar/i.test(title)) return 'Equivalence Partition';
  return 'AI Generated';
}

function toAssistedCsv(results) {
  const header = ['ID', 'Test Case Name', 'Test Type', 'Inputs', 'Expected', 'Status', 'Self-Healed Locators'];
  const rows = results.map((item) => [
    item.id || 'TC??',
    item.title || 'Untitled',
    item.testType || inferTestType(item.title),
    formatCaseInput(item),
    item.expectedStatus === 'VALID' ? 'VALID' : 'INVALID',
    item.result === 'SUCCEED' ? 'SUCCEED' : 'FAILED',
    Number(item.selfHealedLocators || 0),
  ]);
  return [header, ...rows].map((row) => row.map(csvCell).join(',')).join('\n') + '\n';
}

function csvCell(value) {
  return `"${String(value ?? '').replace(/"/g, '""')}"`;
}

function extractText(value) {
  if (!value || typeof value !== 'object') return '';
  if (typeof value.output_text === 'string') return value.output_text;
  if (typeof value.outputText === 'string') return value.outputText;

  const texts = [];
  const seen = new Set();

  function walk(node) {
    if (!node || typeof node !== 'object' || seen.has(node)) return;
    seen.add(node);

    for (const [key, child] of Object.entries(node)) {
      if ((key === 'text' || key === 'output_text' || key === 'outputText') && typeof child === 'string') {
        texts.push(child);
      } else if (child && typeof child === 'object') {
        walk(child);
      }
    }
  }

  walk(value);
  return texts.join('\n').trim();
}

function extractCode(text) {
  const trimmed = text.trim();

  try {
    const parsed = JSON.parse(trimmed);
    if (typeof parsed.code === 'string') return parsed.code;
  } catch {
    // Fall through to code fence extraction.
  }

  const fence = trimmed.match(/```(?:js|javascript)?\s*([\s\S]*?)```/i);
  if (fence) return fence[1].trim();

  return trimmed;
}

function validateSpec(code) {
  const requiredSnippets = [
    "require('@playwright/test')",
    'test(',
    'page.goto',
  ];

  for (const snippet of requiredSnippets) {
    if (!code.includes(snippet)) {
      throw new Error(`Generated spec does not look valid. Missing: ${snippet}`);
    }
  }

  const locatorRequirements = [
    { label: 'day input', snippets: ['#day', "inputCandidates(page, 'day'", 'getByPlaceholder'] },
    { label: 'month input', snippets: ['#month', "inputCandidates(page, 'month'", 'getByPlaceholder'] },
    { label: 'year input', snippets: ['#year', "inputCandidates(page, 'year'", 'getByPlaceholder'] },
    { label: 'result output', snippets: ['#result', 'resultCandidates(page)', 'valid date'] },
  ];

  for (const requirement of locatorRequirements) {
    if (!requirement.snippets.some((snippet) => code.includes(snippet))) {
      throw new Error(`Generated spec does not look valid. Missing locator for: ${requirement.label}`);
    }
  }
}

async function generate(opts) {
  const prompt = buildPrompt();
  if (opts.dryRun) {
    console.log(prompt);
    return;
  }

  console.log(`Calling Gemini model ${opts.model}...`);
  const text = await callGemini(prompt, {
    ...opts,
    systemPrompt: 'You are a senior QA automation engineer. Return only machine-parseable JSON.',
    responseMimeType: 'application/json',
    temperature: 0.2,
  });
  const code = extractCode(text);
  validateSpec(code);

  const outPath = path.join(ROOT, opts.out);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  const header = [
    `// Generated by ${TOPIC_REL}/scripts/gemini-e2e-cli.js.`,
    `// Model: ${opts.model}`,
    `// Generated at: ${new Date().toISOString()}`,
    '// Review before committing if the generated assertions are important.',
    '',
  ].join('\n');

  fs.writeFileSync(outPath, header + code.trim() + '\n', 'utf8');
  console.log(`Wrote ${opts.out}`);
}

async function generateSpecFromSuite(request, approvedSuite, opts) {
  const out = ASSISTED_OUT;
  const parsedCases = parseApprovedSuite(approvedSuite);
  let code;

  console.log(color('[STEP 2] Converting approved suite into Playwright E2E spec...', 'yellow'));

  if (parsedCases.length > 0) {
    code = buildAssistedSpecFromCases(parsedCases);
  } else {
    console.log(color('[AI CONVERT] Could not parse the approved suite directly. Asking Gemini to convert it.', 'yellow'));
    const prompt = buildPromptFromApprovedSuite(request, approvedSuite);
    const text = await callGemini(prompt, {
      ...opts,
      systemPrompt: 'You are a senior QA automation engineer. Return only machine-parseable JSON.',
      responseMimeType: 'application/json',
      temperature: 0.15,
    });
    code = extractCode(text);
  }

  validateSpec(code);

  const outPath = path.join(ROOT, out);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  const header = [
    '// Generated from an approved AI-assisted test suite.',
    '// Source command: npm run ai-test',
    `// Model: ${opts.model}`,
    `// Generated at: ${new Date().toISOString()}`,
    '',
  ].join('\n');

  fs.writeFileSync(outPath, header + code.trim() + '\n', 'utf8');
  console.log(color(`[AI GENERATED SPEC] Wrote ${out}`, 'green'));
  return out;
}

function parseApprovedSuite(suite) {
  const cases = [];
  const blockRegex = /(?:^|\r?\n)\s*-?\s*(TC\d+):\s*([^\r\n]+)([\s\S]*?)(?=(?:\r?\n\s*-?\s*TC\d+:)|$)/gi;
  let match;

  while ((match = blockRegex.exec(suite)) !== null) {
    const id = match[1].toUpperCase();
    const rawTitle = match[2].trim();
    const body = match[3] || '';
    const input = body.match(/\[Input\]\s*Day:\s*"?([^",\r\n]*)"?\s*,\s*Month:\s*"?([^",\r\n]*)"?\s*,\s*Year:\s*"?([^"\r\n]*)"?/i);
    const expected = body.match(/\[Expected\]\s*(VALID|INVALID|ERROR)/i);
    const typeMatch = rawTitle.match(/\[Type:\s*([^\]]+)\]/i);
    const title = rawTitle.replace(/\s*\[Type:\s*[^\]]+\]\s*/i, '').trim() || id;

    if (!input || !expected) continue;

    cases.push({
      id,
      title,
      testType: typeMatch ? typeMatch[1].trim() : inferTestType(title),
      day: input[1].trim(),
      month: input[2].trim(),
      year: input[3].trim(),
      expectedStatus: expected[1].toUpperCase() === 'VALID' ? 'VALID' : 'INVALID',
    });
  }

  return cases;
}

function buildAssistedSpecFromCases(cases) {
  return `
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const VALID_COLOR = 'rgb(0, 128, 0)';
const INVALID_COLOR = 'rgb(255, 0, 0)';
const resultsPath = path.join(process.cwd(), '${ASSISTED_JSON.replace(/\\/g, '/')}');
const results = [];
const STEP_DELAY_MS = Number(process.env.AI_TEST_STEP_DELAY_MS || '${DEFAULT_ASSISTED_STEP_DELAY_MS}');
const SELF_HEAL_LOCATORS = !/^(0|false|no|off)$/i.test(String(process.env.AI_TEST_SELF_HEAL || '1'));
const healEvents = [];

const testCases = ${JSON.stringify(cases, null, 2)};

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

async function healLocator(page, purpose, candidates) {
  const primary = candidates[0];
  if (!SELF_HEAL_LOCATORS) {
    return primary.locator.first();
  }

  for (let index = 0; index < candidates.length; index += 1) {
    const candidate = candidates[index];
    try {
      const locator = candidate.locator.first();
      if (await locator.count() === 0) continue;
      await locator.waitFor({ state: 'visible', timeout: index === 0 ? 700 : 350 });
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

  return primary.locator.first();
}

test.describe('AI-assisted DateTimeChecker E2E Suite', () => {
  test.afterAll(() => {
    fs.mkdirSync(path.dirname(resultsPath), { recursive: true });
    fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2), 'utf8');
  });

  for (const tc of testCases) {
    test(\`\${tc.id}: \${tc.title}\`, async ({ page }) => {
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
`;
}

async function ensureServer(baseUrl) {
  if (await isServerReady(baseUrl)) {
    console.log(color(`[SERVER READY] App is already running at ${baseUrl}`, 'green'));
    return null;
  }

  console.log(color('[SERVER] Starting local Spring Boot server...', 'yellow'));
  const port = new URL(baseUrl).port || '8080';
  const args = ['spring-boot:run', `-Dspring-boot.run.arguments=--server.port=${port}`];

  let child;
  if (process.platform === 'win32') {
    child = spawn('cmd.exe', ['/d', '/s', '/c', ['mvnw.cmd', ...args].join(' ')], {
      cwd: ROOT,
      stdio: ['ignore', 'pipe', 'pipe'],
      env: process.env,
    });
  } else {
    child = spawn('./mvnw', args, {
      cwd: ROOT,
      stdio: ['ignore', 'pipe', 'pipe'],
      env: process.env,
    });
  }

  child.stdout.on('data', (chunk) => {
    const text = chunk.toString();
    if (/Started DatetimecheckerApplication|Tomcat started|BUILD SUCCESS/i.test(text)) {
      process.stdout.write(color('[SERVER] ', 'dim') + text);
    }
  });
  child.stderr.on('data', (chunk) => process.stderr.write(color('[SERVER ERR] ', 'red') + chunk.toString()));

  const started = await waitForServer(baseUrl, 90000, child);
  if (!started) {
    if (!child.killed) child.kill();
    throw new Error(`Spring Boot server did not become ready at ${baseUrl}`);
  }

  console.log(color(`[SERVER READY] ${baseUrl}`, 'green'));
  return child;
}

async function isServerReady(baseUrl) {
  try {
    const res = await fetch(baseUrl, { method: 'GET' });
    return res.ok;
  } catch {
    return false;
  }
}

async function waitForServer(baseUrl, timeoutMs, child) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (child.exitCode !== null) {
      throw new Error(`Spring Boot server exited early with code ${child.exitCode}`);
    }
    if (await isServerReady(baseUrl)) return true;
    await sleep(1000);
  }
  return false;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function run(opts) {
  const specPath = path.join(ROOT, opts.out);
  if (!fs.existsSync(specPath)) {
    throw new Error(`Generated spec not found: ${opts.out}. Run npm run gemini:e2e:generate first.`);
  }

  const env = {
    ...process.env,
    BASE_URL: opts.baseUrl,
    AI_TEST_STEP_DELAY_MS: String(opts.stepDelayMs ?? DEFAULT_ASSISTED_STEP_DELAY_MS),
    AI_TEST_SELF_HEAL: opts.selfHeal ? '1' : '0',
  };
  const usesTopicConfig = isTopicSpec(opts.out);
  const specArg = usesTopicConfig ? path.basename(opts.out) : opts.out;
  const playwrightArgs = ['playwright', 'test', specArg];
  if (usesTopicConfig) playwrightArgs.push('--config', AI_PLAYWRIGHT_CONFIG);
  if (opts.headed) playwrightArgs.push('--headed');
  if (opts.quiet) playwrightArgs.push('--reporter=line');

  let result;
  if (process.platform === 'win32') {
    console.log(`Running: npx.cmd ${formatCommandForDisplay(playwrightArgs)}`);
    result = spawnSync('cmd.exe', ['/d', '/c', 'npx.cmd', ...playwrightArgs], {
      cwd: ROOT,
      stdio: opts.quiet ? 'pipe' : 'inherit',
      encoding: opts.quiet ? 'utf8' : undefined,
      env,
    });
  } else {
    console.log(`Running: npx ${formatCommandForDisplay(playwrightArgs)}`);
    result = spawnSync('npx', playwrightArgs, {
      cwd: ROOT,
      stdio: opts.quiet ? 'pipe' : 'inherit',
      encoding: opts.quiet ? 'utf8' : undefined,
      env,
    });
  }

  if (result.error) throw result.error;
  if (result.status !== 0) {
    if (opts.exitOnFailure === false) {
      return {
        status: result.status,
        stdout: result.stdout || '',
        stderr: result.stderr || '',
      };
    }
    process.exit(result.status);
  }

  return {
    status: 0,
    stdout: result.stdout || '',
    stderr: result.stderr || '',
  };
}

function isTopicSpec(out) {
  const normalized = String(out).replace(/\\/g, '/');
  return normalized.startsWith(`${TOPIC_REL}/e2e/`);
}

function formatCommandForDisplay(args) {
  return args.map((arg) => /\s/.test(arg) ? `"${arg}"` : arg).join(' ');
}

async function main() {
  const opts = parseArgs(process.argv);

  if (opts.command === 'help') {
    usage();
    return;
  }

  if (opts.command === 'doctor') {
    await doctor(opts);
    return;
  }

  if (opts.command === 'chat') {
    await chat(opts);
    return;
  }

  if (opts.command === 'assist') {
    await assist(opts);
    return;
  }

  if (opts.command === 'generate') {
    await generate(opts);
    return;
  }

  if (opts.command === 'run') {
    run(opts);
    return;
  }

  if (opts.command === 'all') {
    await generate(opts);
    run(opts);
    return;
  }

  throw new Error(`Unknown command: ${opts.command}`);
}

main().catch((err) => {
  console.error(`\n${err.message}`);
  process.exit(1);
});
