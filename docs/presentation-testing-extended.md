# Nội dung thuyết trình – Phần "Testing mở rộng" (Unit / E2E / Performance / Mobile / CI-CD)

> Phần này tiếp nối sau phần chính **API Testing (Postman/Newman)** của 3 bạn còn lại.
> Mạch kể chuyện: "API đã được test đúng chức năng rồi — vậy còn **logic bên trong**, **trải nghiệm người dùng thật**, **chịu tải**, **trên mobile**, và **tự động hoá** thì sao?" → mỗi mục trả lời 1 câu hỏi đó.

---

## Slide 1 — Mở đầu phần

**Tiêu đề:** Testing mở rộng: từ Unit đến CI/CD

**Nội dung:**
- Nhắc lại: 3 bạn trước đã trình bày phần API Testing (Postman/Newman), verify **đầu vào/đầu ra của endpoint** `/api/datetime/check`.
- Câu hỏi đặt ra:
  1. Logic xử lý bên trong (`isLeapYear`, validate field) có đúng từng dòng không? → **Unit Test**
  2. Người dùng thật dùng giao diện web thì có ra đúng kết quả không? → **E2E Test**
  3. App có chạy tốt trên **điện thoại** không? → **Mobile Testing**
  4. App chịu được **bao nhiêu người dùng cùng lúc**? → **Performance/Load Test**
  5. Làm sao để **mọi lần push code đều tự kiểm tra hết** các loại test trên? → **CI/CD**
- Tất cả 5 loại test này dùng **chung 1 bộ dữ liệu `test-data.json` (57 test case)** sinh từ `generate-test-data.js` → đảm bảo tính nhất quán xuyên suốt project (điểm nhấn quan trọng để show "tính hệ thống").

---

## Slide 2 — Testing Pyramid của project

**Nội dung (vẽ pyramid hoặc sơ đồ layer):**

```
        ┌────────────────────┐
        │  E2E / Mobile UI    │  ← chậm nhất, gần người dùng nhất
        │  (Playwright/Maestro)│
        ├────────────────────┤
        │   API Test (Newman)│  ← phần của 4 bạn còn lại
        ├────────────────────┤
        │     Unit Test       │  ← nhanh nhất, test logic thuần Java
        └────────────────────┘
        + Performance (k6)  → cắt ngang, đo tốc độ/tải ở tầng API
        + CI/CD             → "đường ống" chạy tất cả các tầng tự động
```

- Nhấn mạnh: cùng 1 bộ test-data, nhưng **mỗi tầng kiểm tra một khía cạnh khác nhau** của cùng một tính năng "check ngày hợp lệ".

---

## Slide 3 — Unit Test (JUnit 5)

**Công cụ:** JUnit 5 (Parameterized Test) + Jackson (đọc JSON)

**Nội dung:**
- Test trực tiếp **class `DateTimeCheckerService`** bằng Java, không cần chạy server, không cần network.
- 2 nhóm test trong `DateTimeCheckerServiceTest.java`:
  1. **Parameterized test** chạy qua **toàn bộ 57 case** trong `test-data.json` → gọi `service.check()`, so sánh `valid` và `field` kỳ vọng.
  2. **4 unit test riêng** cho `isLeapYear()`:
     - `2000` → true (chia hết 400)
     - `1900` → false (chia hết 100 nhưng không 400)
     - `2024` → true (chia hết 4)
     - `2023` → false

**Chạy:**
```bash
./mvnw test
```

**Điểm nhấn khi thuyết trình:**
- Unit test là **lớp phòng thủ đầu tiên** — chạy trong vài giây, phát hiện lỗi logic trước khi build/deploy.
- Vì dùng cùng `test-data.json`, **không cần viết lại test case** — chỉ cần thêm dòng vào file JSON là cả Unit/API/E2E/k6 đều test theo.

---

## Slide 4 — E2E Test Desktop (Playwright)

**Công cụ:** Playwright (`@playwright/test`), project "Desktop Chrome"

**Nội dung:**
- Giả lập **người dùng thật** trên giao diện web (`index.html`): điền `#day`, `#month`, `#year`, bấm nút, đọc kết quả `#result`.
- Assertion: kiểm tra **màu chữ** của kết quả — xanh (`rgb(0,128,0)`) nếu hợp lệ, đỏ (`rgb(255,0,0)`) nếu không — tức là test luôn **cả UI feedback**, không chỉ dữ liệu JSON.
- Chạy qua **toàn bộ 57 case** từ `test-data.json` (1 test/case).

**Chạy:**
```bash
npx playwright test --project="Desktop Chrome"
```

**Điểm nhấn:**
- API test (Newman) verify response JSON; E2E test verify **người dùng có nhìn thấy đúng kết quả trên màn hình** — 2 lớp bổ sung cho nhau, không thay thế nhau.

---

## Slide 5 — Mobile Testing: Flutter Web + Playwright Mobile

**Bối cảnh:** Project có thêm **mobile app viết bằng Flutter Web** (`mobile_app/`), cùng chức năng check ngày, build ra và nhúng vào Spring Boot tại `/mobile/index.html`.

**Thử thách kỹ thuật (đáng kể khi thuyết trình):**
- Flutter Web dùng renderer **CanvasKit** → toàn bộ UI vẽ lên `<canvas>`, **không có input DOM** như `#day/#month/#year` để `page.fill()`.
- Giải pháp: dùng **keyboard traversal** — `Tab` để chuyển focus giữa các ô, `keyboard.type()` để nhập từng ký tự, `Tab + Enter` để bấm nút Check.

**3 nhóm test trong `mobile.spec.js` (project "iPhone 14 Pro Max" – viewport 430x932, có touch):**
1. **Load test**: app Flutter load thành công (`flt-glass-pane` attached), URL chứa `/mobile/`.
2. **`[Demo canvas]`**: nhập liệu trực tiếp trên canvas (23 case subset), chụp screenshot từng case → **dùng cho video demo trực quan**.
3. **`[Mobile]`**: gọi API `/api/datetime/check` từ **mobile browser context** (qua `fetch`), so sánh kết quả với 23 case subset — verify backend hoạt động đúng khi gọi từ thiết bị mobile.

**Subset 23 case được chọn có chủ đích** (từ `helpers/test-data.js`):
- 5 case đầu (ngày đầu tháng), 5 case ngày cuối tháng, 8 case năm nhuận, 5 case invalid → đại diện đủ các nhóm chính của 57 case mà không chạy hết (vì canvas chậm).

**Chạy:**
```bash
npx playwright test --project="iPhone 14 Pro Max"

# Xem trực quan nhập liệu trên canvas
npx playwright test --project="iPhone 14 Pro Max" -g "Demo canvas" --headed --workers=1
```

---

## Slide 6 — Mobile UI Flow Test (Maestro) — *bonus / future work*

**Công cụ:** Maestro (`maestro/check-valid-date.yaml`)

**Nội dung:**
- Khai báo flow: mở `/mobile/index.html`, tap vào 3 ô theo % tọa độ màn hình, nhập `15 / 6 / 2000`, tap nút Check, chụp screenshot `valid-date-result`.
- **Trạng thái thật, nói rõ trong slide**: ⚠️ chưa setup môi trường Maestro, flow mới ở dạng khai báo, **chưa chạy/verify thực tế**.

**Cách trình bày tích cực:**
- Đây là layer test **gần với người dùng thật nhất** (chạm/gõ trên thiết bị/emulator thật), khác với Playwright (giả lập browser).
- Nêu đây là **hướng mở rộng tiếp theo** của project — thể hiện tư duy roadmap, không chỉ dừng ở những gì đã làm.

---

## Slide 7 — Performance / Load Test (k6)

**Công cụ:** k6 (`k6/load-test.js`)

**Nội dung:**
- Test **endpoint API** chịu tải, không phải UI.
- Dùng lại `test-data.json`: mỗi virtual user **random chọn 1 trong 57 case** để gửi request → traffic giả lập đa dạng, không lặp lại 1 pattern.

**Kịch bản tải (stages):**
| Giai đoạn | Thời gian | Số user đồng thời |
|---|---|---|
| Ramp-up | 10s | 0 → 10 |
| Peak | 20s | → 50 |
| Ramp-down | 10s | → 0 |

**Tiêu chí pass (thresholds):**
- 95% request phải có `http_req_duration < 500ms` (`p(95)<500`)
- Tỉ lệ lỗi `http_req_failed < 1%`

**Mỗi request còn check:**
- status = 200
- response có field `valid`
- `valid` đúng với `expectedValid` của test-data → **k6 không chỉ đo tốc độ, mà còn verify độ chính xác dưới tải**.

**Chạy:**
```bash
k6 run k6/load-test.js
```

**Lưu ý khi thuyết trình:** k6 **không nằm trong CI/CD** vì load test nên chạy riêng trên môi trường staging, tránh ảnh hưởng pipeline mỗi lần push.

---

## Slide 8 — CI/CD (GitHub Actions)

**File:** `.github/workflows/api-test.yml` — chạy trên mọi `push`

**Sơ đồ pipeline (5 job):**

```
push code
   │
   ▼
unit-test (build + ./mvnw test)
   │
   ├──► api-test     (build app → start → Newman 57 case)
   ├──► e2e-test     (build app → start → Playwright Desktop Chrome)
   ├──► mobile-test  (build app → start → Playwright iPhone 14 Pro Max, bỏ "Demo canvas")
   └──► k6-test      (build app → start → k6 load test)
```

**Điểm kỹ thuật đáng nói:**
- `unit-test` chạy trước, các job còn lại đều `needs: unit-test` và chạy **song song** sau đó → fail nhanh nếu logic cơ bản sai, tiết kiệm thời gian CI.
- Mỗi job tự **build jar, start Spring Boot ở background, poll `/api/datetime/check` tới khi sẵn sàng (tối đa 30 lần x 3s)** rồi mới chạy test — đảm bảo môi trường độc lập, đáng tin cậy.
- `mobile-test` dùng `--grep-invert "Demo canvas"` → bỏ nhóm test chỉ để demo trực quan (chậm, có `waitForTimeout` dài), giữ lại phần verify logic qua `[Mobile]`.
- k6 **có job riêng trong CI** (khác với khuyến nghị ở slide 7 nói k6 nên chạy ngoài CI cho production — ở đây project chạy trong CI vì là pipeline demo/học tập, có thể nêu như một trade-off để thảo luận).

**Điểm nhấn:** Đây là nơi **tổng hợp tất cả các loại test đã trình bày** (Unit, API, E2E, Mobile, Performance) thành một quy trình tự động — kết nối toàn bộ buổi thuyết trình lại với nhau.

---

## Slide 9 — Tổng kết phần

**Bảng tổng hợp:**

| Loại test | Công cụ | Phạm vi | Số case |
|---|---|---|---|
| Unit Test | JUnit 5 | Logic Java (`DateTimeCheckerService`) | 57 + 4 |
| E2E Desktop | Playwright | Giao diện web `/` | 57 |
| Mobile (Flutter Web) | Playwright | `/mobile/index.html` + API qua mobile context | 23 (subset) + 1 demo canvas + 1 load |
| Mobile UI Flow | Maestro | Chạm/gõ thật trên thiết bị | 1 flow (chưa verify) |
| Performance | k6 | `/api/datetime/check` chịu tải 50 user | random từ 57 |
| CI/CD | GitHub Actions | Tất cả các loại trên | mọi push |

**Câu chốt:** "1 bộ dữ liệu test (`test-data.json`) — 6 góc nhìn kiểm thử khác nhau — tự động hoá hoàn toàn qua CI/CD."

---

## Phần demo video (script gợi ý — ~3-5 phút cho phần này)

1. **(15s)** Giới thiệu nhanh: "Sau khi API đã được test ở phần trước, nhóm sẽ demo các lớp test bổ sung."
2. **(30s) Unit Test**: chạy `./mvnw test` trong terminal, show output pass 61 test (57+4), zoom vào 1-2 test `isLeapYear`.
3. **(45s) E2E Desktop**: chạy `npx playwright test --project="Desktop Chrome"` với `--headed` + `slowMo`, quay vài case (1 valid → xanh, 1 invalid → đỏ).
4. **(45-60s) Mobile**:
   - Mở `/mobile/index.html` trên trình duyệt, resize/emulate mobile.
   - Chạy `npx playwright test --project="iPhone 14 Pro Max" -g "Demo canvas" --headed --workers=1` — quay cảnh Tab/type trên canvas Flutter.
5. **(30s) Performance**: chạy `k6 run k6/load-test.js`, show summary cuối (p95 latency, error rate đạt threshold).
6. **(30-45s) CI/CD**: mở tab Actions trên GitHub, show pipeline 5 job chạy xanh sau khi push, click vào 1 job để xem log.
7. **(15s)** Kết: tổng kết bảng ở Slide 9, chuyển sang Q&A.

> Gợi ý quay màn hình theo đúng thứ tự trên để video map trực tiếp với thứ tự slide — người xem dễ theo dõi.
