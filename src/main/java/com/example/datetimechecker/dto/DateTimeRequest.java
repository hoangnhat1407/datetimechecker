package com.example.datetimechecker.dto;

/**
 * Input giữ nguyên dạng chuỗi để service tự validate
 * (người dùng có thể nhập "abc", "1.5", chuỗi rỗng...).
 */
public record DateTimeRequest(String day, String month, String year) {
}
