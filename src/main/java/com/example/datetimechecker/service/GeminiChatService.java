package com.example.datetimechecker.service;

import com.example.datetimechecker.dto.GeminiChatRequest;
import com.example.datetimechecker.dto.GeminiChatResponse;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Map;

@Service
public class GeminiChatService {

    private static final String GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta";

    private final ObjectMapper mapper;
    private final HttpClient httpClient;
    private final String apiKey;
    private final String model;

    public GeminiChatService(
            ObjectMapper mapper,
            @Value("${gemini.api-key:${GEMINI_API_KEY:}}") String apiKey,
            @Value("${gemini.model:${GEMINI_MODEL:gemini-3.1-flash-lite}}") String model) {
        this.mapper = mapper;
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.model = model == null || model.isBlank() ? "gemini-3.1-flash-lite" : model.trim();
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(20))
                .build();
    }

    public GeminiChatResponse chat(GeminiChatRequest request) {
        if (apiKey.isBlank()) {
            return GeminiChatResponse.failure(
                    "Missing GEMINI_API_KEY. Set it before starting Spring Boot.",
                    model
            );
        }

        String userMessage = request.message() == null ? "" : request.message().trim();
        if (userMessage.isBlank()) {
            return GeminiChatResponse.failure("Message must not be empty.", model);
        }

        try {
            String responseText = callGemini(buildSystemPrompt(request.mode()), userMessage);
            return GeminiChatResponse.success(responseText, model);
        } catch (IOException e) {
            return GeminiChatResponse.failure("Gemini request failed: " + e.getMessage(), model);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return GeminiChatResponse.failure("Gemini request was interrupted.", model);
        } catch (RuntimeException e) {
            return GeminiChatResponse.failure(e.getMessage(), model);
        }
    }

    private String callGemini(String systemPrompt, String userMessage) throws IOException, InterruptedException {
        String endpoint = GEMINI_API_BASE + "/models/"
                + URLEncoder.encode(model.replaceFirst("^models/", ""), StandardCharsets.UTF_8)
                + ":generateContent";

        Map<String, Object> payload = Map.of(
                "systemInstruction", Map.of(
                        "parts", List.of(Map.of("text", systemPrompt))
                ),
                "contents", List.of(Map.of(
                        "role", "user",
                        "parts", List.of(Map.of("text", userMessage))
                )),
                "generationConfig", Map.of(
                        "temperature", 0.2
                )
        );

        HttpRequest httpRequest = HttpRequest.newBuilder()
                .uri(URI.create(endpoint))
                .timeout(Duration.ofSeconds(60))
                .header("Content-Type", "application/json")
                .header("x-goog-api-key", apiKey)
                .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(payload)))
                .build();

        HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
        JsonNode body = parseJson(response.body());

        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            String message = body.path("error").path("message").asText(response.body());
            throw new IllegalStateException("Gemini API failed (" + response.statusCode() + "): " + message);
        }

        String text = body.path("candidates")
                .path(0)
                .path("content")
                .path("parts")
                .path(0)
                .path("text")
                .asText("");

        if (text.isBlank()) {
            throw new IllegalStateException("Gemini returned an empty response.");
        }

        return text;
    }

    private JsonNode parseJson(String raw) {
        try {
            return mapper.readTree(raw);
        } catch (IOException e) {
            throw new IllegalStateException("Gemini returned non-JSON response: " + raw);
        }
    }

    private String buildSystemPrompt(String mode) {
        String projectContext = """
                You are integrated into a DateTimeChecker testing project.
                The app validates day/month/year strings using Gregorian calendar rules.
                API: POST /api/datetime/check with JSON { "day": string, "month": string, "year": string }.
                Response: { "valid": boolean, "message": string, "field": string | null }.
                Valid year range is 1000 to 3000. Day range is 1 to 31. Month range is 1 to 12.
                Leap-year rule: divisible by 400 is leap, divisible by 100 but not 400 is not leap, otherwise divisible by 4 is leap.
                Existing tools: JUnit, Postman/Newman, Playwright, k6, Docker, GitHub Actions.
                """;

        if ("test-cases".equalsIgnoreCase(mode)) {
            return projectContext + """
                    Create concise, practical test cases for this project.
                    Prefer a table with ID, input day/month/year, expected valid, expected field, and reason.
                    Include boundary values, equivalence classes, invalid non-numeric input, month-length rules, and leap-year cases.
                    If asked for automation, include Playwright or JUnit code snippets that fit this project.
                    """;
        }

        return projectContext + """
                Answer as a helpful QA automation assistant.
                Keep responses clear, actionable, and focused on this project's testing workflow.
                """;
    }
}
