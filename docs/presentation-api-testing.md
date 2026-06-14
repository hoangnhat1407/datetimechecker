# Nội dung thuyết trình – Phần chính "API Testing" (Postman/Newman) — 3 người

> Đây là phần chính của buổi thuyết trình, đi trước phần "Testing mở rộng" (Unit/E2E/Mobile/Performance/CI-CD).
> Chia thành **3 mảng**, mỗi người 1 mảng, theo đúng trình tự làm việc thật của API testing: **Đặc tả API → Thiết kế test case → Thực thi & báo cáo**.

---

# PHẦN 1 (Người 1): Đặc tả API & quy tắc nghiệp vụ

## Slide 1 — Giới thiệu API cần test

**Endpoint:** `POST /api/datetime/check`

**Request:**
```json
{ "day": "29", "month": "2", "year": "2000" }
```

**Response (hợp lệ):**
```json
{ "valid": true, "message": "29/02/2000 is a valid date.", "field": null }
```

**Response (không hợp lệ):**
```json
{ "valid": false, "message": "Day must be in range 1 to 31.", "field": "day" }
```

**Điểm nhấn:**
- `day/month/year` đều là **string**, không phải số — vì phải test cả trường hợp nhập chữ, số thập phân, ký tự đặc biệt.
- API **luôn trả HTTP 200**, kể cả khi dữ liệu không hợp lệ — vì "ngày không hợp lệ" là **kết quả nghiệp vụ**, không phải lỗi HTTP. → Đây là điểm dễ bị test sai nếu chỉ check status code mà không check field `valid`.
- Có thêm endpoint `POST /api/datetime/clear` (stateless, luôn trả `{valid: true, message: "Cleared successfully."}`) — đơn giản, dùng để demo reset form trên UI.

---

## Slide 2 — Quy tắc validate (business logic cần test)

Thứ tự kiểm tra trong `DateTimeCheckerService`: **day → month → year → tính hợp lệ của ngày trong tháng/năm đó**.

| Bước | Điều kiện | Nếu sai → `field` | Message mẫu |
|---|---|---|---|
| 1 | `day` phải là số nguyên | `"day"` | "Day must be a number." |
| 2 | `day` ∈ [1, 31] | `"day"` | "Day must be in range 1 to 31." |
| 3 | `month` phải là số nguyên | `"month"` | "Month must be a number." |
| 4 | `month` ∈ [1, 12] | `"month"` | "Month must be in range 1 to 12." |
| 5 | `year` phải là số nguyên | `"year"` | "Year must be a number." |
| 6 | `year` ∈ [1000, 3000] | `"year"` | "Year must be in range 1000 to 3000." |
| 7 | Ngày phải tồn tại trong tháng (theo số ngày của tháng + năm nhuận) | `null` | "... is an invalid date." |

**Quy tắc năm nhuận (Gregorian)** — quan trọng vì là phần logic "khó" nhất:
- Chia hết cho 400 → nhuận (VD: 2000, 2400)
- Chia hết cho 100 nhưng không chia hết cho 400 → **không** nhuận (VD: 1900, 2100, 2200, 2300)
- Chia hết cho 4 (còn lại) → nhuận (VD: 2024)

**Điểm nhấn khi thuyết trình:** chính vì validate có **thứ tự ưu tiên** (dừng ở lỗi đầu tiên gặp), test case phải được thiết kế để **mỗi case chỉ cô lập 1 điều kiện** — đây là cầu nối sang phần 2 (thiết kế test case).

---

# PHẦN 2 (Người 2): Thiết kế bộ test case (57 case)

## Slide 3 — Phương pháp thiết kế test

- Dùng kỹ thuật **Equivalence Partitioning** (chia lớp tương đương) + **Boundary Value Analysis** (giá trị biên).
- Toàn bộ 57 case được sinh tự động bằng script `generate-test-data.js` → ghi ra `test-data.json`, **dùng chung cho mọi loại test trong project** (API/Unit/E2E/k6) — đảm bảo 1 nguồn sự thật duy nhất, không lệch dữ liệu giữa các nhóm test.

## Slide 4 — 8 nhóm test case (tổng 57 case, 28 valid / 29 invalid)

| # | Nhóm | Số case | Mục tiêu | Ví dụ |
|---|---|---|---|---|
| 1 | Ngày đầu mỗi tháng (năm 2000) | 12 | Valid - giá trị biên dưới của `day` | `1/1/2000` → valid |
| 2 | Ngày cuối mỗi tháng (năm 2001, không nhuận) | 12 | Valid - giá trị biên trên của `day` theo từng tháng | `28/2/2001`, `31/1/2001`... |
| 3 | `29/2` ở năm nhuận | 4 | Valid - quy tắc năm nhuận đúng | `29/2/2000`, `29/2/2400` |
| 4 | `29/2` ở năm **không** nhuận | 4 | Invalid - quy tắc năm nhuận (case "bẫy" chia hết 100) | `29/2/1900`, `29/2/2100` |
| 5 | `day` ngoài [1-31] | 4 | Invalid, `field="day"` | `0`, `32`, `99`, `-1` |
| 6 | `month` ngoài [1-12] | 3 | Invalid, `field="month"` | `0`, `13`, `99` |
| 7 | `year` ngoài [1000-3000] | 3 | Invalid, `field="year"` | `999`, `3001`, `0` |
| 8 | Input không phải số nguyên (áp cho cả day/month/year) | 15 | Invalid, kiểm tra `tryParseInt` | `"abc"`, `""`, `" "`, `"1.5"`, `"!@#"` |

**Điểm nhấn:**
- Nhóm 4 (`29/2` năm không nhuận) là **case "bẫy"** kinh điển — kiểm tra đúng công thức `chia 100 nhưng không chia 400`, dễ bị code sai nếu chỉ check `% 4`.
- Nhóm 8 nhân 5 giá trị (`"abc"`, `""`, `" "`, `"1.5"`, `"!@#"`) × 3 field (day/month/year) = 15 case — test **input "rác"** mà người dùng thật có thể gõ vào.

## Slide 5 — Cấu trúc 1 test case trong `test-data.json`

```json
{
  "day": "29", "month": "2", "year": "1900",
  "expectedValid": false, "expectedField": null,
  "description": "29/2/1900 - không phải năm nhuận, không hợp lệ"
}
```

- `expectedValid` / `expectedField` chính là **oracle** (kết quả mong đợi) để assertion so sánh.
- `description` dùng làm **tên test** hiển thị trong báo cáo Postman/Newman/JUnit → dễ đọc khi có case fail.

---

# PHẦN 3 (Người 3): Thực thi test — Postman & Newman

## Slide 6 — Cấu trúc Postman Collection

Collection **"DateTimeChecker API"** (file `DateTimeChecker API.postman_collection.json`):
- 1 request: `POST {{baseUrl}}/api/datetime/check`
- Body raw JSON dùng **biến Postman**: `{{day}}`, `{{month}}`, `{{year}}` → giá trị lấy từ file dữ liệu khi chạy theo iteration.
- Tab **Tests** (post-response script):
```javascript
const desc = pm.iterationData.get("description") || "";

pm.test(`[${desc}] Status 200`, () =>
    pm.response.to.have.status(200));

pm.test(`[${desc}] valid matches expected`, () => {
    const json = pm.response.json();
    const expected = pm.iterationData.get("expectedValid");
    pm.expect(json.valid).to.eql(expected);
});
```
- Mỗi iteration → **2 assertion**: status code 200, và `valid` đúng kỳ vọng → với 57 case = **114 assertion** mỗi lần chạy.

## Slide 7 — Chạy thủ công trong Postman (demo)

1. Mở collection **DateTimeChecker API**.
2. **Run collection** → chọn file `test-data.json` làm data file.
3. Postman lặp qua 57 dòng dữ liệu, mỗi dòng gửi 1 request + chạy script test ở Slide 6.
4. Xem kết quả: **Pass/Fail từng case**, tên hiển thị = `description` trong data.

## Slide 8 — Chạy tự động bằng Newman (CLI)

```bash
newman run "DateTimeChecker API.postman_collection.json" \
  --iteration-data test-data.json \
  --env-var "baseUrl=http://localhost:8080"
```

- Newman = phiên bản **command-line của Postman runner** → chạy được trong terminal/CI, không cần mở GUI.
- Output: bảng tổng hợp request/assertion (pass/fail), thời gian response, tổng kết cuối (`# requests`, `# assertions`, `# failed`).
- **Cầu nối sang CI/CD**: trong `.github/workflows/api-test.yml`, job `api-test` cài Newman bằng `npm install -g newman` rồi chạy đúng lệnh trên sau khi build & start Spring Boot — tức là **mọi lần push code, 57 case × 2 assertion này tự động chạy lại**.

## Slide 9 — Đọc kết quả & xử lý khi fail

- Khi 1 case fail, Newman in ra **đúng `description`** của case đó (VD: `"29/2/1900 - không phải năm nhuận, không hợp lệ"`) → biết ngay **logic nào sai** mà không cần đoán.
- Vì `test-data.json` dùng chung toàn project: nếu API test fail ở 1 case, **Unit test và E2E test cũng sẽ fail ở case tương ứng** → dễ khoanh vùng lỗi nằm ở tầng nào (logic Java / endpoint / UI).

---

## Gợi ý phân chia thời gian thuyết trình (phần API Testing, ~6-8 phút)

| Người | Nội dung | Thời gian |
|---|---|---|
| 1 | Đặc tả API + quy tắc nghiệp vụ (Slide 1-2) | ~2-3 phút |
| 2 | Thiết kế 57 test case (Slide 3-5) | ~2-3 phút |
| 3 | Demo Postman + Newman + kết nối CI/CD (Slide 6-9) | ~2-3 phút |

## Script demo video (phần API Testing — nối tiếp trước phần "Testing mở rộng")

1. **(20s)** Show endpoint trong Postman: gửi 1 request mẫu `29/2/2000`, xem response valid.
2. **(20s)** Gửi 1 request invalid (`32/1/2000`) → show response có `field: "day"`.
3. **(30s)** Mở tab Tests, giải thích nhanh đoạn script assertion.
4. **(30-40s)** **Run collection** với `test-data.json` → quay cảnh 57 case chạy, dừng lại ở 1-2 case "bẫy" (29/2/1900) để nhấn mạnh năm nhuận.
5. **(20-30s)** Chuyển qua terminal, chạy lệnh Newman → show output tổng kết (114/114 assertions pass).
6. → Chuyển tiếp mượt sang phần "Testing mở rộng" (đã có script ở `presentation-testing-extended.md`).
