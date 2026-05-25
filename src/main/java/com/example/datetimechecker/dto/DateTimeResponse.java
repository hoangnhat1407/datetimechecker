package com.example.datetimechecker.dto;

public class DateTimeResponse {
    private boolean valid;
    private String message;
    private String field;   // null nếu không lỗi

    public DateTimeResponse(boolean valid, String message) {
        this.valid = valid;
        this.message = message;
    }

    public DateTimeResponse(boolean valid, String message, String field) {
        this.valid = valid;
        this.message = message;
        this.field = field;
    }

    public boolean isValid() { return valid; }
    public String getMessage() { return message; }
    public String getField() { return field; }
}
