package com.example.datetimechecker.service;

import com.example.datetimechecker.dto.DateTimeRequest;
import com.example.datetimechecker.dto.DateTimeResponse;
import org.springframework.stereotype.Service;

/**
 * Validate ngày/tháng/năm nhập dạng chuỗi theo lịch Gregorian.
 * Thứ tự kiểm tra: day → month → year (mỗi field: là số → trong range),
 * cuối cùng mới kiểm tra ngày có tồn tại trong tháng/năm đó không.
 */
@Service
public class DateTimeCheckerService {

    // Số ngày tối đa của từng tháng, index 1-12 (không tính năm nhuận)
    private static final int[] DAYS_IN_MONTH = {
        0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    };

    public DateTimeResponse check(DateTimeRequest request) {
        Integer day = tryParseInt(request.day());
        if (day == null) {
            return fieldError("day", "Day must be a number.");
        }
        if (day < 1 || day > 31) {
            return fieldError("day", "Day must be in range 1 to 31.");
        }

        Integer month = tryParseInt(request.month());
        if (month == null) {
            return fieldError("month", "Month must be a number.");
        }
        if (month < 1 || month > 12) {
            return fieldError("month", "Month must be in range 1 to 12.");
        }

        Integer year = tryParseInt(request.year());
        if (year == null) {
            return fieldError("year", "Year must be a number.");
        }
        if (year < 1000 || year > 3000) {
            return fieldError("year", "Year must be in range 1000 to 3000.");
        }

        String date = String.format("%02d/%02d/%04d", day, month, year);
        return isValidDate(day, month, year)
            ? new DateTimeResponse(true, date + " is a valid date.")
            : new DateTimeResponse(false, date + " is an invalid date.");
    }

    /**
     * Kiểm tra ngày tồn tại trong tháng/năm (day/month/year đã trong range hợp lệ).
     * Tháng 2 phụ thuộc năm nhuận, các tháng khác theo DAYS_IN_MONTH.
     */
    public boolean isValidDate(int day, int month, int year) {
        int maxDay = (month == 2)
            ? (isLeapYear(year) ? 29 : 28)
            : DAYS_IN_MONTH[month];
        return day <= maxDay;
    }

    /**
     * Năm nhuận Gregorian: chia hết cho 4, trừ các năm chia hết cho 100
     * mà không chia hết cho 400.
     */
    public boolean isLeapYear(int year) {
        if (year % 400 == 0) return true;
        if (year % 100 == 0) return false;
        return year % 4 == 0;
    }

    private static Integer tryParseInt(String raw) {
        if (raw == null) return null;
        try {
            return Integer.parseInt(raw.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static DateTimeResponse fieldError(String field, String message) {
        return new DateTimeResponse(false, message, field);
    }
}
