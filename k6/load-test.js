import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 10  },  // tăng dần lên 10 users
    { duration: '20s', target: 50  },  // tăng lên 50 users
    { duration: '10s', target: 0   },  // giảm về 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% request phải dưới 500ms
    http_req_failed:   ['rate<0.01'],  // tỉ lệ lỗi dưới 1%
  },
};

const BASE_URL = 'http://localhost:8080';

const testCases = [
  { day: '1',   month: '1',  year: '2000' },  // valid
  { day: '29',  month: '2',  year: '2000' },  // valid leap year
  { day: '29',  month: '2',  year: '1900' },  // invalid
  { day: '31',  month: '4',  year: '2023' },  // invalid
  { day: 'abc', month: '1',  year: '2000' },  // invalid input
];

export default function () {
  // chọn random 1 test case mỗi lần
  const body = testCases[Math.floor(Math.random() * testCases.length)];

  const res = http.post(
    `${BASE_URL}/api/datetime/check`,
    JSON.stringify(body),
    { headers: { 'Content-Type': 'application/json' } }
  );

  check(res, {
    'status is 200':        (r) => r.status === 200,
    'response has valid':   (r) => JSON.parse(r.body).valid !== undefined,
    'response time < 500ms':(r) => r.timings.duration < 500,
  });

  sleep(1);
}
