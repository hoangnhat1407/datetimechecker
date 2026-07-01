package com.example.datetimechecker;

import com.example.datetimechecker.dto.DateTimeRequest;
import com.example.datetimechecker.dto.DateTimeResponse;
import com.example.datetimechecker.service.DateTimeCheckerService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.TestMethodOrder;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertEquals;

@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class CheckDateTest {

    private final DateTimeCheckerService service = new DateTimeCheckerService();

    private record CaseResult(String utcid, String day, String month, String year,
                              boolean expectedValid, boolean actualValid,
                              String expectedField, String actualField,
                              String description) {
        boolean passed() {
            return expectedValid == actualValid
                    && ((expectedField == null && actualField == null)
                    || (expectedField != null && expectedField.equals(actualField)));
        }
    }

    private static final List<CaseResult> RESULTS = new ArrayList<>();

    static Stream<Arguments> checkDateCases() throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        JsonNode root = mapper.readTree(new File("test-data.json"));
        List<Arguments> args = new ArrayList<>();

        int index = 1;
        for (JsonNode node : root) {
            String expectedField = node.has("expectedField") && !node.get("expectedField").isNull()
                    ? node.get("expectedField").asText()
                    : null;
            args.add(Arguments.of(
                    String.format("UTCID%02d", index++),
                    node.get("day").asText(),
                    node.get("month").asText(),
                    node.get("year").asText(),
                    node.get("expectedValid").asBoolean(),
                    expectedField,
                    node.get("description").asText()
            ));
        }

        return args.stream();
    }

    @Order(1)
    @ParameterizedTest(name = "{0}: checkDate(day={1}, month={2}, year={3})")
    @MethodSource("checkDateCases")
    @DisplayName("CheckDate - test cases from test-data.json")
    void checkDate(String utcid, String day, String month, String year,
                   boolean expectedValid, String expectedField, String description) {
        DateTimeResponse actual = service.check(new DateTimeRequest(day, month, year));

        RESULTS.add(new CaseResult(
                utcid, day, month, year,
                expectedValid, actual.valid(),
                expectedField, actual.field(),
                description
        ));

        assertEquals(expectedValid, actual.valid(), description);
        assertEquals(expectedField, actual.field(), description);
    }

    @AfterAll
    static void printReport() {
        RESULTS.sort((a, b) -> a.utcid().compareTo(b.utcid()));

        long passed = RESULTS.stream().filter(CaseResult::passed).count();
        long failed = RESULTS.size() - passed;

        StringBuilder sb = new StringBuilder();
        String line = "+----------+-----+-------+------+----------+--------+---------------+-------------+--------+";
        sb.append('\n');
        sb.append("============ UNIT TEST REPORT: CheckDate(day, month, year) ============\n");
        sb.append(line).append('\n');
        sb.append(String.format("| %-8s | %-3s | %-5s | %-4s | %-8s | %-6s | %-13s | %-11s | %-6s |%n",
                "UTCID", "Day", "Month", "Year", "Expected", "Actual", "ExpectedField", "ActualField", "Result"));
        sb.append(line).append('\n');
        for (CaseResult r : RESULTS) {
            sb.append(String.format("| %-8s | %-3s | %-5s | %-4s | %-8s | %-6s | %-13s | %-11s | %-6s |%n",
                    r.utcid(), r.day(), r.month(), r.year(),
                    r.expectedValid(), r.actualValid(),
                    String.valueOf(r.expectedField()), String.valueOf(r.actualField()),
                    r.passed() ? "PASS" : "FAIL"));
        }
        sb.append(line).append('\n');
        sb.append(String.format("Total: %d cases | PASS: %d | FAIL: %d%n",
                RESULTS.size(), passed, failed));
        sb.append("========================================================================\n");

        System.out.println(sb);
    }
}
