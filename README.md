# DateTimeChecker SWT301

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

### Mobile testing bằng double-click

To run native mobile testing without manual setup, double-click:

```bat
Topic 4-Mobile testing\run.bat
```

The script installs Android SDK command-line tools, Flutter SDK, Maestro CLI, creates an Android emulator, starts the Spring Boot backend on port 8080, builds the Flutter APK, installs it on the emulator, then runs the Maestro native app test.

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

**GET** `/api/datetime/check?day=29&month=2&year=2000`

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

Coverage: chạy parameterized test trên toàn bộ 57 case từ `shared/data/test-data.json` (day/month/year không phải số, out of range, năm nhuận, tháng thiếu/đủ...) + 4 unit test riêng cho logic `isLeapYear`.

---

## 2. API Test (Postman + Newman)

### Chạy thủ công trong Postman
- Mở collection **DateTimeChecker API** trong `Topic 2-API testing/DateTimeChecker API.postman_collection.json`
- Tab **Body** → raw → JSON → điền `{"day":"...","month":"...","year":"..."}`
- Tab **Scripts → Post-response** → viết assertions
- **Run collection** → chọn `shared/data/test-data.json` → Run

### Chạy tự động bằng Newman (CLI)
```bash
newman run "Topic 2-API testing/DateTimeChecker API.postman_collection.json" \
  --iteration-data shared/data/test-data.json \
  --env-var "baseUrl=http://localhost:8080"
```

`shared/data/test-data.json` (sinh từ `shared/scripts/generate-test-data.js`, dùng chung cho mọi loại test trong dự án) chứa 57 test case với các ngày hợp lệ và không hợp lệ — Newman chạy iteration qua toàn bộ tập này.

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

Coverage: project **Desktop Chrome** (`shared/e2e/test.spec.js`) chạy qua giao diện web với toàn bộ 57 case từ `shared/data/test-data.json` — cùng bộ dữ liệu chia sẻ với Unit Test và API Test ở trên.

### Chạy riêng theo project (Desktop / Mobile)

Desktop Playwright config is in `playwright.config.js`; mobile Playwright config is in `Topic 4-mobile testing/playwright.mobile.config.js`:
- **Desktop Chrome** (`shared/e2e/test.spec.js`) — test trang web thường tại `/`
- **iPhone 14 Pro Max** (`Topic 4-mobile testing/e2e/mobile.spec.js`) — giả lập viewport mobile (430x932, touch) để test app Flutter Web tại `/mobile/index.html`: app load thành công, API trả đúng kết quả từ mobile context, chạy lại tập con test case từ `shared/data/test-data.json`

```bash
npx playwright test --project="Desktop Chrome"
npx playwright test --config "Topic 4-mobile testing/playwright.mobile.config.js" --project="iPhone 14 Pro Max"

# Xem trực quan từng thao tác nhập liệu trên canvas Flutter
npx playwright test --config "Topic 4-mobile testing/playwright.mobile.config.js" --project="iPhone 14 Pro Max" -g "Demo canvas" --headed --workers=1
```

---

## 3.1. AI-assisted E2E Test (Gemini API)

Topic 7 contains the Gemini-powered AI-assisted testing workflow.

Quick run:

```bat
Topic 7-AI assisted and e2e testing\run.bat
```

Generated AI specs, approved suites, JSON results, and text/CSV reports are stored under `Topic 7-AI assisted and e2e testing/`.

See `Topic 7-AI assisted and e2e testing/docs/gemini-e2e-cli.md` for details.
---

## 4. Native Mobile App Testing (Flutter APK + Maestro)

Topic 4 has been converted from Mobile Web testing to Native Mobile App testing.

```bat
Topic 4-Mobile testing\run.bat
```

The runner bootstraps Android SDK command-line tools, Flutter SDK, Maestro CLI, creates an AVD named `test_device`, starts Spring Boot on port `8080`, runs `flutter create .` if native folders are missing, builds a debug APK, installs it on the emulator, and runs `maestro/check-valid-date.yaml` against `appId: com.example.mobile_app`.

The native Flutter app calls the backend through Android emulator host routing:

```text
http://10.0.2.2:8080/api/datetime/check
```

## 4.1. Mobile App (Legacy Flutter Web Notes)

Ứng dụng Flutter Web cùng chức năng kiểm tra ngày (`Topic 4-mobile testing/mobile_app/`), dùng để demo & test trải nghiệm trên thiết bị di động. Build ra được nhúng vào Spring Boot tại `src/main/resources/static/mobile/` và phục vụ cùng server backend.

### Chạy ở chế độ phát triển
```bash
cd "Topic 4-mobile testing/mobile_app"
flutter run -d chrome
```

### Build & deploy vào Spring Boot
```bash
cd "Topic 4-mobile testing/mobile_app"
flutter build web
# copy nội dung build/web/* sang src/main/resources/static/mobile/
```

Sau khi Spring Boot chạy, truy cập: http://localhost:8080/mobile/index.html

---

## 5. Mobile UI Flow Test (Maestro)

Mô phỏng thao tác chạm & gõ trực tiếp trên giao diện mobile (`Topic 4-mobile testing/maestro/check-valid-date.yaml`): mở app, nhập ngày/tháng/năm, bấm kiểm tra, chụp ảnh kết quả từng bước — gần với trải nghiệm người dùng thật nhất trong các loại test ở đây.

> ⚠️ Tạm thời chưa chạy/test được (chưa setup môi trường Maestro) — flow này mới ở dạng khai báo, chưa được verify thực tế.

### Cài đặt (1 lần)
Theo hướng dẫn: https://maestro.mobile.dev

### Chạy (Spring Boot phải đang chạy)
```bash
maestro test "Topic 4-mobile testing/maestro/check-valid-date.yaml"
```

---

## 6. Load Test (k6)

Test hiệu năng: bao nhiêu user đồng thời app vẫn chạy ổn.

### Cài đặt
Tải tại: https://dl.k6.io/msi/k6-latest-amd64.msi

### Chạy (Spring Boot phải đang chạy)
```bash
k6 run shared/k6/load-test.js
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

CI/CD demo files are grouped in `Topic 3-CICD/`.

Quick demo:

```bat
Topic 3-CICD\run.bat
```

The script updates `Topic 3-CICD/DEMO_CI_NOTE.md`, creates a commit, pushes branch `hoangnhat-draft`, and GitHub Actions starts automatically because the workflow runs on push.
After all jobs finish, the workflow generates `Topic 3-CICD/CICD_REPORT.md` in the GitHub Actions run summary and uploads it as the `cicd-report` artifact.

The actual workflow file stays at `.github/workflows/api-test.yml` because GitHub only detects workflow files from `.github/workflows`.

Pipeline jobs:
1. Build Spring Boot
2. Run Maven unit tests
3. Run Newman API tests
4. Run Playwright E2E tests
5. Run Playwright mobile tests
6. Run k6 load test

Xem ket qua tai tab **Actions** tren GitHub.

```
Topic 3-CICD\run.bat -> push code -> GitHub Actions -> reports/logs
```

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
│   ├── main/resources/static/mobile/      ← Flutter Web build (deploy từ Topic 4-mobile testing/mobile_app/)
│   └── test/java/.../DateTimeCheckerServiceTest.java
├── Topic 2-API testing/                    ← API testing bundle
│   ├── DateTimeChecker API.postman_collection.json
│   ├── presentation-api-testing.md
│   ├── run.bat
│   └── run-api-test.ps1
|-- Topic 3-CICD/                           <- CI/CD GitHub Actions demo
|   |-- run.bat                             <- one-click commit + push trigger
|   |-- DEMO_CI_NOTE.md                     <- timestamp note for demo commits
|   |-- CICD_REPORT.md                      <- CI/CD report template/artifact format
|   `-- README.md
├── Topic 4-mobile testing/                                ← Mobile testing bundle
│   ├── run.bat                             ← one-click mobile test runner
│   ├── playwright.mobile.config.js         ← Playwright mobile config
│   ├── mobile_app/                         ← Flutter Web mobile app source
│   ├── e2e/mobile.spec.js                  ← Playwright mobile tests
│   └── maestro/check-valid-date.yaml       ← Maestro mobile UI flow test
├── shared/
│   ├── data/test-data.json                ← dữ liệu test dùng chung
│   ├── docs/                              ← tài liệu chung
│   ├── e2e/
│   │   ├── helpers/test-data.js           ← loader test-data.json dùng chung cho các spec
│   │   └── test.spec.js                   ← Playwright E2E tests (Desktop Chrome)
│   ├── k6/load-test.js                    ← k6 load tests
│   └── scripts/generate-test-data.js      ← sinh shared/data/test-data.json
├── .github/workflows/
│   └── api-test.yml                       ← CI/CD pipeline
├── Dockerfile                             ← multi-stage build (Maven → JRE)
├── docker-compose.yml                     ← app + e2e-test + mobile-test (Playwright)
└── playwright.config.js                   ← project Desktop Chrome
```
