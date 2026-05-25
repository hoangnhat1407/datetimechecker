package com.example.datetimechecker.service;

import com.example.datetimechecker.dto.DateTimeRequest;
import com.example.datetimechecker.dto.DateTimeResponse;
import org.springframework.stereotype.Service;

@Service
public class DateTimeCheckerService {

    // Số ngày tối đa của từng tháng (không tính năm nhuận)
    private static final int[] DAYS_IN_MONTH = {
        0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    };

    public DateTimeResponse check(DateTimeRequest request) {

        // --- 1. Validate Day: phải là số nguyên ---
        int day;
        try {
            day = Integer.parseInt(request.getDay().trim());
        } catch (NumberFormatException e) {
            return new DateTimeResponse(false,
                "Day must be a number.", "day");
        }

        // --- 2. Validate Day: phải trong range 1-31 ---
        if (day < 1 || day > 31) {
            return new DateTimeResponse(false,
                "Day must be in range 1 to 31.", "day");
        }

        // --- 3. Validate Month: phải là số nguyên ---
        int month;
        try {
            month = Integer.parseInt(request.getMonth().trim());
        } catch (NumberFormatException e) {
            return new DateTimeResponse(false,
                "Month must be a number.", "month");
        }

        // --- 4. Validate Month: phải trong range 1-12 ---
        if (month < 1 || month > 12) {
            return new DateTimeResponse(false,
                "Month must be in range 1 to 12.", "month");
        }

        // --- 5. Validate Year: phải là số nguyên ---
        int year;
        try {
            year = Integer.parseInt(request.getYear().trim());
        } catch (NumberFormatException e) {
            return new DateTimeResponse(false,
                "Year must be a number.", "year");
        }

        // --- 6. Validate Year: phải trong range 1000-3000 ---
        if (year < 1000 || year > 3000) {
            return new DateTimeResponse(false,
                "Year must be in range 1000 to 3000.", "year");
        }

        // --- 7. Check logic ngày hợp lệ (Gregorian calendar) ---
        boolean isValid = isValidDate(day, month, year);
        String dateStr = String.format("%02d/%02d/%04d", day, month, year);

        if (isValid) {
            return new DateTimeResponse(true,
                dateStr + " is a valid date.");
        } else {
            return new DateTimeResponse(false,
                dateStr + " is an invalid date.");
        }
    }

    /**
     * Kiểm tra ngày hợp lệ theo lịch Gregorian.
     * Theo flowchart trong tài liệu:
     * - Tháng 2: kiểm tra năm nhuận
     * - Các tháng khác: kiểm tra số ngày tối đa
     */
    boolean isValidDate(int day, int month, int year) {
        int maxDay;
        if (month == 2) {
            maxDay = isLeapYear(year) ? 29 : 28;
        } else {
            maxDay = DAYS_IN_MONTH[month];
        }
        return day <= maxDay;
    }

    /**
     * Kiểm tra năm nhuận theo lịch Gregorian:
     * - Chia hết cho 400 → nhuận
     * - Chia hết cho 100 nhưng không chia hết cho 400 → không nhuận
     * - Chia hết cho 4 → nhuận
     * - Còn lại → không nhuận
     */
    boolean isLeapYear(int year) {
        if (year % 400 == 0) return true;
        if (year % 100 == 0) return false;
        return year % 4 == 0;
    }
}
