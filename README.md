# DateTimeChecker

Spring Boot REST API kiểm tra ngày/tháng/năm hợp lệ theo lịch Gregorian.

---

## Khởi động app

```bash
./mvnw spring-boot:run
```

Truy cập giao diện: http://localhost:8080

### Chạy bằng Docker

Dockerfile build multi-stage (Maven build ngay trong Docker, không cần JDK trên máy):

```bash
docker compose up --build app
# hoặc: docker build -t datetimechecker . && docker run -p 8080:8080 datetimechecker
```

### Mobile testing bằng Docker

`docker-compose.yml` có sẵn 2 service test dùng image Playwright chính thức,
tự chờ app healthy rồi chạy test qua `BASE_URL=http://app:8080`:

```bash
# E2E desktop (Desktop Chrome, 57 case)
docker compose run --rm e2e-test

# Mobile (iPhone 14 Pro Max emulation, bỏ nhóm Demo canvas)
docker compose run --rm mobile-test
```

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

Coverage: chạy parameterized test trên toàn bộ 57 case từ `test-data.json` (day/month/year không phải số, out of range, năm nhuận, tháng thiếu/đủ...) + 4 unit test riêng cho logic `isLeapYear`.

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

`test-data.json` (sinh từ `generate-test-data.js`, dùng chung cho mọi loại test trong dự án) chứa 57 test case với các ngày hợp lệ và không hợp lệ — Newman chạy iteration qua toàn bộ tập này.

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

Coverage: project **Desktop Chrome** (`test.spec.js`) chạy qua giao diện web với toàn bộ 57 case từ `test-data.json` — cùng bộ dữ liệu chia sẻ với Unit Test và API Test ở trên.

### Chạy riêng theo project (Desktop / Mobile)

`playwright.config.js` định nghĩa 2 project:
- **Desktop Chrome** (`e2e/test.spec.js`) — test trang web thường tại `/`
- **iPhone 14 Pro Max** (`e2e/mobile.spec.js`) — giả lập viewport mobile (430x932, touch) để test app Flutter Web tại `/mobile/index.html`: app load thành công, API trả đúng kết quả từ mobile context, chạy lại tập con test case từ `test-data.json`

```bash
npx playwright test --project="Desktop Chrome"
npx playwright test --project="iPhone 14 Pro Max"

# Xem trực quan từng thao tác nhập liệu trên canvas Flutter
npx playwright test --project="iPhone 14 Pro Max" -g "Demo canvas" --headed --workers=1
```

---

## 4. Mobile App (Flutter Web)

Ứng dụng Flutter Web cùng chức năng kiểm tra ngày (`mobile_app/`), dùng để demo & test trải nghiệm trên thiết bị di động. Build ra được nhúng vào Spring Boot tại `src/main/resources/static/mobile/` và phục vụ cùng server backend.

### Chạy ở chế độ phát triển
```bash
cd mobile_app
flutter run -d chrome
```

### Build & deploy vào Spring Boot
```bash
cd mobile_app
flutter build web
# copy nội dung build/web/* sang src/main/resources/static/mobile/
```

Sau khi Spring Boot chạy, truy cập: http://localhost:8080/mobile/index.html

---

## 5. Mobile UI Flow Test (Maestro)

Mô phỏng thao tác chạm & gõ trực tiếp trên giao diện mobile (`maestro/check-valid-date.yaml`): mở app, nhập ngày/tháng/năm, bấm kiểm tra, chụp ảnh kết quả từng bước — gần với trải nghiệm người dùng thật nhất trong các loại test ở đây.

> ⚠️ Tạm thời chưa chạy/test được (chưa setup môi trường Maestro) — flow này mới ở dạng khai báo, chưa được verify thực tế.

### Cài đặt (1 lần)
Theo hướng dẫn: https://maestro.mobile.dev

### Chạy (Spring Boot phải đang chạy)
```bash
maestro test maestro/check-valid-date.yaml
```

---

## 6. Load Test (k6)

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

## 7. CI/CD (GitHub Actions)

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
│   ├── main/resources/static/index.html   ← giao diện web thường
│   ├── main/resources/static/mobile/      ← Flutter Web build (deploy từ mobile_app/)
│   └── test/java/.../DateTimeCheckerServiceTest.java
├── mobile_app/                             ← Flutter Web mobile app (source)
│   └── lib/main.dart
├── e2e/
│   ├── helpers/test-data.js               ← loader test-data.json dùng chung cho các spec
│   ├── test.spec.js                       ← Playwright E2E tests (Desktop Chrome)
│   └── mobile.spec.js                     ← Playwright mobile tests (iPhone 14 Pro Max)
├── maestro/
│   └── check-valid-date.yaml              ← Maestro mobile UI flow test
├── k6/
│   └── load-test.js                       ← k6 load tests
├── .github/workflows/
│   └── api-test.yml                       ← CI/CD pipeline
├── Dockerfile                             ← multi-stage build (Maven → JRE)
├── docker-compose.yml                     ← app + e2e-test + mobile-test (Playwright)
├── DateTimeChecker API.postman_collection.json
├── generate-test-data.js                  ← sinh test-data.json
├── test-data.json
└── playwright.config.js                   ← project Desktop Chrome + iPhone 14 Pro Max
```
