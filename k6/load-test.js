import http from 'k6/http';
import { check, sleep } from 'k6';

// Đọc toàn bộ test case từ file dùng chung
const testData = JSON.parse(open('../test-data.json'));

export const options = {
  stages: [
    { duration: '10s', target: 10 },  // tăng dần lên 10 users
    { duration: '20s', target: 50 },  // tăng lên 50 users
    { duration: '10s', target: 0  },  // giảm về 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% request phải dưới 500ms
    http_req_failed:   ['rate<0.01'],  // tỉ lệ lỗi dưới 1%
  },
};

const BASE_URL = 'http://localhost:8080';

export default function () {
  // Chọn random 1 test case từ bộ dùng chung
  const tc = testData[Math.floor(Math.random() * testData.length)];

  const res = http.post(
    `${BASE_URL}/api/datetime/check`,
    JSON.stringify({ day: tc.day, month: tc.month, year: tc.year }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  check(res, {
    'status is 200':          (r) => r.status === 200,
    'response has valid':     (r) => JSON.parse(r.body).valid !== undefined,
    'valid matches expected':  (r) => JSON.parse(r.body).valid === tc.expectedValid,
    'response time < 500ms':  (r) => r.timings.duration < 500,
  });

  sleep(1);
}
