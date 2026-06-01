package com.example.datetimechecker;

import com.example.datetimechecker.dto.DateTimeRequest;
import com.example.datetimechecker.dto.DateTimeResponse;
import com.example.datetimechecker.service.DateTimeCheckerService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.*;

class DateTimeCheckerServiceTest {

    private final DateTimeCheckerService service = new DateTimeCheckerService();

    // ===== PARAMETERIZED TESTS từ test-data.json =====

    @ParameterizedTest(name = "[{index}] {3}")
    @MethodSource("loadTestCases")
    void validateDate(String day, String month, String year,
                      String description, boolean expectedValid, String expectedField) {
        DateTimeResponse res = service.check(new DateTimeRequest(day, month, year));
        assertEquals(expectedValid, res.isValid(), description);
        if (expectedField != null) {
            assertEquals(expectedField, res.getField(), description);
        }
    }

    static Stream<Arguments> loadTestCases() throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        JsonNode root = mapper.readTree(new File("test-data.json"));
        List<Arguments> args = new ArrayList<>();
        for (JsonNode node : root) {
            String expectedField = node.has("expectedField") && !node.get("expectedField").isNull()
                    ? node.get("expectedField").asText()
                    : null;
            args.add(Arguments.of(
                    node.get("day").asText(),
                    node.get("month").asText(),
                    node.get("year").asText(),
                    node.get("description").asText(),
                    node.get("expectedValid").asBoolean(),
                    expectedField
            ));
        }
        return args.stream();
    }

    // ===== UNIT TESTS cho logic isLeapYear (không có trong test-data.json) =====

    @Test
    @DisplayName("isLeapYear(2000) = true - chia hết 400")
    void leapYear_2000() {
        assertTrue(service.isLeapYear(2000));
    }

    @Test
    @DisplayName("isLeapYear(1900) = false - chia hết 100 nhưng không 400")
    void leapYear_1900() {
        assertFalse(service.isLeapYear(1900));
    }

    @Test
    @DisplayName("isLeapYear(2024) = true - chia hết 4")
    void leapYear_2024() {
        assertTrue(service.isLeapYear(2024));
    }

    @Test
    @DisplayName("isLeapYear(2023) = false - không chia hết 4")
    void leapYear_2023() {
        assertFalse(service.isLeapYear(2023));
    }
}
