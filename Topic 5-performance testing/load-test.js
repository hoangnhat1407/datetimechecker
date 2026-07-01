import http from 'k6/http';
import { check, sleep } from 'k6';

const testData = JSON.parse(open('./test-data.json'));
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const DEMO_MODE = (__ENV.DEMO_MODE || 'quick').toLowerCase();

const quickStages = [
  { duration: '3s', target: 5 },
  { duration: '7s', target: 15 },
  { duration: '5s', target: 0 },
];

const fullStages = [
  { duration: '10s', target: 10 },
  { duration: '20s', target: 50 },
  { duration: '10s', target: 0 },
];

export const options = {
  stages: DEMO_MODE === 'full' ? fullStages : quickStages,
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
    checks: ['rate>0.99'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'max'],
};

export default function () {
  const tc = testData[Math.floor(Math.random() * testData.length)];

  const res = http.post(
    `${BASE_URL}/api/datetime/check`,
    JSON.stringify({ day: tc.day, month: tc.month, year: tc.year }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  let body = {};
  try {
    body = res.json();
  } catch (error) {
    body = {};
  }

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response has valid': () => body.valid !== undefined,
    'valid matches expected': () => body.valid === tc.expectedValid,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);
}
