package com.example.datetimechecker.dto;

/**
 * @param field tên field gây lỗi (day/month/year), null nếu không lỗi field cụ thể
 */
public record DateTimeResponse(boolean valid, String message, String field) {

    public DateTimeResponse(boolean valid, String message) {
        this(valid, message, null);
    }
}
