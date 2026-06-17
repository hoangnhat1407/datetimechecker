package com.example.datetimechecker;

import com.example.datetimechecker.service.DateTimeCheckerService;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.TestMethodOrder;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Unit test cho hàm {@link DateTimeCheckerService#dayInMonth(Integer, int)}.
 *
 * <p>15 test case (UTCID01..UTCID15) lấy đúng từ sheet <b>DayInMonth</b> trong
 * file "Template_Unit Test Case.xls". Cột tham chiếu để đối chiếu logic là
 * Month / Year / Return (số ngày kỳ vọng) — KHÔNG dùng cột Passed/Failed của
 * sheet vì đó chỉ là dữ liệu mẫu đã điền sẵn của template.</p>
 *
 * <p>Sau khi chạy xong toàn bộ case, {@code @AfterAll} in ra một báo cáo bảng
 * hoàn chỉnh (kèm tổng Passed/Failed) ngay trên console.</p>
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class DayInMonthTest {

    private final DateTimeCheckerService service = new DateTimeCheckerService();

    // Bản ghi kết quả từng case, dùng để dựng báo cáo cuối cùng trong @AfterAll.
    private record CaseResult(String utcid, String month, int year,
                              int expected, int actual, String type) {
        boolean passed() {
            return expected == actual;
        }
    }

    private static final List<CaseResult> RESULTS = new ArrayList<>();

    /**
     * 15 case từ sheet DayInMonth.
     * Cột: UTCID | month (null = tháng không nhập) | year | expected (số ngày) | type (N/A/B)
     */
    static Stream<Arguments> dayInMonthCases() {
        return Stream.of(
                Arguments.of("UTCID01", (Integer) 1,   2020, 31, "B"),
                Arguments.of("UTCID02", (Integer) 2,   2021, 28, "N"),
                Arguments.of("UTCID03", (Integer) 2,   2019, 28, "N"),
                Arguments.of("UTCID04", (Integer) 15,  2021, 0,  "A"),
                Arguments.of("UTCID05", (Integer) 2,   10,   28, "N"),
                Arguments.of("UTCID06", (Integer) (-10), 2026, 0, "A"),
                Arguments.of("UTCID07", (Integer) 3,   2024, 31, "N"),
                Arguments.of("UTCID08", (Integer) null, 2026, 0, "A"),
                Arguments.of("UTCID09", (Integer) 4,   2026, 30, "N"),
                Arguments.of("UTCID10", (Integer) 2,   1000, 28, "N"),
                Arguments.of("UTCID11", (Integer) 2,   1900, 28, "N"),
                Arguments.of("UTCID12", (Integer) 2,   2000, 29, "N"),
                Arguments.of("UTCID13", (Integer) null, 2020, 0, "A"),
                Arguments.of("UTCID14", (Integer) 2,   2024, 29, "N"),
                Arguments.of("UTCID15", (Integer) 2,   2026, 28, "N")
        );
    }

    @Order(1)
    @ParameterizedTest(name = "{0}: dayInMonth(month={1}, year={2}) = {3}")
    @MethodSource("dayInMonthCases")
    @DisplayName("DayInMonth - 15 test case (UTCID01..UTCID15)")
    void dayInMonth(String utcid, Integer month, int year, int expected, String type) {
        int actual = service.dayInMonth(month, year);

        // Ghi lại kết quả TRƯỚC khi assert để báo cáo cuối cùng có đủ 15 dòng,
        // kể cả khi một case fail (assert ném exception).
        RESULTS.add(new CaseResult(utcid, String.valueOf(month), year, expected, actual, type));

        assertEquals(expected, actual,
                () -> utcid + " FAIL: dayInMonth(month=" + month + ", year=" + year
                        + ") kỳ vọng " + expected + " nhưng nhận " + actual);
    }

    @AfterAll
    static void printReport() {
        RESULTS.sort((a, b) -> a.utcid().compareTo(b.utcid()));

        long passed = RESULTS.stream().filter(CaseResult::passed).count();
        long failed = RESULTS.size() - passed;

        StringBuilder sb = new StringBuilder();
        String line = "+----------+--------+-------+----------+--------+------+--------+";
        sb.append('\n');
        sb.append("============ UNIT TEST REPORT: DayInMonth(month, year) ============\n");
        sb.append(line).append('\n');
        sb.append(String.format("| %-8s | %-6s | %-5s | %-8s | %-6s | %-4s | %-6s |%n",
                "UTCID", "Month", "Year", "Expected", "Actual", "Type", "Result"));
        sb.append(line).append('\n');
        for (CaseResult r : RESULTS) {
            sb.append(String.format("| %-8s | %-6s | %-5d | %-8d | %-6d | %-4s | %-6s |%n",
                    r.utcid(), r.month(), r.year(), r.expected(), r.actual(),
                    r.type(), r.passed() ? "PASS" : "FAIL"));
        }
        sb.append(line).append('\n');
        sb.append(String.format("Total: %d cases | PASS: %d | FAIL: %d%n",
                RESULTS.size(), passed, failed));
        sb.append("==================================================================\n");

        System.out.println(sb);
    }
}
