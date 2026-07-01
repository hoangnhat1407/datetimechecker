package com.example.datetimechecker.controller;

import com.example.datetimechecker.dto.GeminiChatRequest;
import com.example.datetimechecker.dto.GeminiChatResponse;
import com.example.datetimechecker.service.GeminiChatService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/gemini")
public class GeminiChatController {

    private final GeminiChatService service;

    public GeminiChatController(GeminiChatService service) {
        this.service = service;
    }

    @PostMapping("/chat")
    public ResponseEntity<GeminiChatResponse> chat(@RequestBody GeminiChatRequest request) {
        GeminiChatResponse response = service.chat(request);
        return ResponseEntity.ok(response);
    }
}
