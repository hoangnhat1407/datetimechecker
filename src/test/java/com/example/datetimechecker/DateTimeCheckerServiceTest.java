package com.example.datetimechecker;

import com.example.datetimechecker.dto.DateTimeRequest;
import com.example.datetimechecker.dto.DateTimeResponse;
import com.example.datetimechecker.service.DateTimeCheckerService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class DateTimeCheckerServiceTest {

    private DateTimeCheckerService service;

    @BeforeEach
    void setUp() {
        service = new DateTimeCheckerService();
    }

    // ===== DAY VALIDATION =====

    @Test
    @DisplayName("Day không phải số → lỗi")
    void day_notANumber_returnsError() {
        DateTimeResponse res = service.check(new DateTimeRequest("abc", "1", "2000"));
        assertFalse(res.isValid());
        assertEquals("day", res.getField());
    }

    @Test
    @DisplayName("Day = 0 → out of range")
    void day_zero_outOfRange() {
        DateTimeResponse res = service.check(new DateTimeRequest("0", "1", "2000"));
        assertFalse(res.isValid());
        assertEquals("day", res.getField());
    }

    @Test
    @DisplayName("Day = 32 → out of range")
    void day_32_outOfRange() {
        DateTimeResponse res = service.check(new DateTimeRequest("32", "1", "2000"));
        assertFalse(res.isValid());
        assertEquals("day", res.getField());
    }

    // ===== MONTH VALIDATION =====

    @Test
    @DisplayName("Month không phải số → lỗi")
    void month_notANumber_returnsError() {
        DateTimeResponse res = service.check(new DateTimeRequest("1", "xyz", "2000"));
        assertFalse(res.isValid());
        assertEquals("month", res.getField());
    }

    @Test
    @DisplayName("Month = 13 → out of range")
    void month_13_outOfRange() {
        DateTimeResponse res = service.check(new DateTimeRequest("1", "13", "2000"));
        assertFalse(res.isValid());
        assertEquals("month", res.getField());
    }

    // ===== YEAR VALIDATION =====

    @Test
    @DisplayName("Year không phải số → lỗi")
    void year_notANumber_returnsError() {
        DateTimeResponse res = service.check(new DateTimeRequest("1", "1", "abc"));
        assertFalse(res.isValid());
        assertEquals("year", res.getField());
    }

    @Test
    @DisplayName("Year = 999 → out of range")
    void year_999_outOfRange() {
        DateTimeResponse res = service.check(new DateTimeRequest("1", "1", "999"));
        assertFalse(res.isValid());
        assertEquals("year", res.getField());
    }

    @Test
    @DisplayName("Year = 3001 → out of range")
    void year_3001_outOfRange() {
        DateTimeResponse res = service.check(new DateTimeRequest("1", "1", "3001"));
        assertFalse(res.isValid());
        assertEquals("year", res.getField());
    }

    // ===== VALID DATES =====

    @Test
    @DisplayName("1/1/2000 → valid")
    void validDate_1Jan2000() {
        DateTimeResponse res = service.check(new DateTimeRequest("1", "1", "2000"));
        assertTrue(res.isValid());
    }

    @Test
    @DisplayName("29/2/2000 → valid (năm nhuận chia hết 400)")
    void validDate_29Feb2000_leapYear400() {
        DateTimeResponse res = service.check(new DateTimeRequest("29", "2", "2000"));
        assertTrue(res.isValid());
    }

    @Test
    @DisplayName("29/2/2004 → valid (năm nhuận chia hết 4)")
    void validDate_29Feb2004_leapYear4() {
        DateTimeResponse res = service.check(new DateTimeRequest("29", "2", "2004"));
        assertTrue(res.isValid());
    }

    @Test
    @DisplayName("31/12/3000 → valid (biên trên)")
    void validDate_31Dec3000() {
        DateTimeResponse res = service.check(new DateTimeRequest("31", "12", "3000"));
        assertTrue(res.isValid());
    }

    // ===== INVALID DATES =====

    @Test
    @DisplayName("29/2/1900 → invalid (chia hết 100 nhưng không 400)")
    void invalidDate_29Feb1900_notLeap() {
        DateTimeResponse res = service.check(new DateTimeRequest("29", "2", "1900"));
        assertFalse(res.isValid());
    }

    @Test
    @DisplayName("31/4/2023 → invalid (tháng 4 có 30 ngày)")
    void invalidDate_31April() {
        DateTimeResponse res = service.check(new DateTimeRequest("31", "4", "2023"));
        assertFalse(res.isValid());
    }

    @Test
    @DisplayName("30/2/2023 → invalid (tháng 2 không năm nhuận max 28)")
    void invalidDate_30Feb2023() {
        DateTimeResponse res = service.check(new DateTimeRequest("30", "2", "2023"));
        assertFalse(res.isValid());
    }

    // ===== LEAP YEAR UNIT TESTS =====

    @Test
    @DisplayName("isLeapYear(2000) = true")
    void leapYear_2000() {
        assertTrue(service.isLeapYear(2000));
    }

    @Test
    @DisplayName("isLeapYear(1900) = false")
    void leapYear_1900() {
        assertFalse(service.isLeapYear(1900));
    }

    @Test
    @DisplayName("isLeapYear(2024) = true")
    void leapYear_2024() {
        assertTrue(service.isLeapYear(2024));
    }

    @Test
    @DisplayName("isLeapYear(2023) = false")
    void leapYear_2023() {
        assertFalse(service.isLeapYear(2023));
    }
}
