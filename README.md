# DateTimeChecker

Spring Boot REST API kiểm tra ngày/tháng/năm hợp lệ theo lịch Gregorian.

---

## Khởi động app

```bash
./mvnw spring-boot:run
```

Truy cập giao diện: http://localhost:8080

---

## API

**POST** `/api/datetime/check`

Request:
```json
{ "day": "29", "month": "2", "year": "2000" }
```

Response:
```json
{ "valid": true, "message": "29/02/2000 is a valid date.", "field": null }
```

---

## 1. Unit Test (REST Assured / JUnit)

Test logic validate trực tiếp trong Java, không cần chạy server.

```bash
./mvnw test
```

Coverage: 17 test cases — day/month/year không phải số, out of range, năm nhuận, tháng thiếu/đủ.

---

## 2. API Test (Postman + Newman)

### Chạy thủ công trong Postman
- Mở collection **DateTimeChecker API**
- Tab **Body** → raw → JSON → điền `{"day":"...","month":"...","year":"..."}`
- Tab **Scripts → Post-response** → viết assertions
- **Run collection** → chọn `test-data.json` → Run

### Chạy tự động bằng Newman (CLI)
```bash
newman run "DateTimeChecker API.postman_collection.json" \
  --iteration-data test-data.json \
  --env-var "baseUrl=http://localhost:8080"
```

`test-data.json` chứa 6 test case với các ngày hợp lệ và không hợp lệ.

---

## 3. E2E Test (Playwright)

Giả lập người dùng thật: mở trình duyệt, điền form, bấm nút, kiểm tra kết quả.

### Cài đặt (1 lần)
```bash
npm install @playwright/test
npx playwright install chromium
```

### Chạy (Spring Boot phải đang chạy)
```bash
# Chạy có hiện trình duyệt (để xem)
npx playwright test

# Chạy nhanh không hiện trình duyệt
npx playwright test --headed=false
```

Để xem chậm từng bước, sửa `playwright.config.js`:
```js
slowMo: 1000  // 1 giây giữa mỗi thao tác
```

Coverage: 5 test case — valid date, leap year, not leap year, invalid day, invalid month.

---

## 4. Load Test (k6)

Test hiệu năng: bao nhiêu user đồng thời app vẫn chạy ổn.

### Cài đặt
Tải tại: https://dl.k6.io/msi/k6-latest-amd64.msi

### Chạy (Spring Boot phải đang chạy)
```bash
k6 run k6/load-test.js
```

Kịch bản:
- 10 giây: tăng dần lên 10 users
- 20 giây: tăng lên 50 users đồng thời
- 10 giây: giảm về 0

Tiêu chí pass:
- 95% request phải dưới 500ms
- Tỉ lệ lỗi dưới 1%

---

## 5. CI/CD (GitHub Actions)

Mỗi lần push code lên GitHub, pipeline tự động:
1. Build Spring Boot
2. Chạy Newman (API tests)
3. Chạy Playwright (E2E tests)

Xem kết quả tại tab **Actions** trên GitHub.

```
push code → GitHub Actions → Build → API Test → E2E Test → ✅/❌
```

> k6 không tích hợp vào CI/CD vì load test thường chạy riêng trên môi trường staging, không phải mỗi lần push.

---

## Cấu trúc project

```
datetimechecker/
├── src/
│   ├── main/java/com/example/datetimechecker/
│   │   ├── controller/DateTimeCheckerController.java
│   │   ├── service/DateTimeCheckerService.java
│   │   └── dto/DateTimeRequest.java, DateTimeResponse.java
│   ├── main/resources/static/index.html   ← giao diện
│   └── test/java/.../DateTimeCheckerServiceTest.java
├── e2e/
│   └── test.spec.js                       ← Playwright E2E tests
├── k6/
│   └── load-test.js                       ← k6 load tests
├── .github/workflows/
│   └── api-test.yml                       ← CI/CD pipeline
├── DateTimeChecker API.postman_collection.json
├── test-data.json
└── playwright.config.js
```
