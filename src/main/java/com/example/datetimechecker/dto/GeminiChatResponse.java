package com.example.datetimechecker.dto;

public record GeminiChatResponse(boolean ok, String reply, String error, String model) {

    public static GeminiChatResponse success(String reply, String model) {
        return new GeminiChatResponse(true, reply, null, model);
    }

    public static GeminiChatResponse failure(String error, String model) {
        return new GeminiChatResponse(false, null, error, model);
    }
}
