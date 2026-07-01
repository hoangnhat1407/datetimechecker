package com.example.datetimechecker.controller;

import com.example.datetimechecker.dto.DateTimeRequest;
import com.example.datetimechecker.dto.DateTimeResponse;
import com.example.datetimechecker.service.DateTimeCheckerService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/datetime")
public class DateTimeCheckerController {

    private final DateTimeCheckerService service;

    public DateTimeCheckerController(DateTimeCheckerService service) {
        this.service = service;
    }

    /**
     * POST /api/datetime/check
     * Body: { "day": "29", "month": "2", "year": "2000" }
     */
    @PostMapping("/check")
    public ResponseEntity<DateTimeResponse> check(@RequestBody DateTimeRequest request) {
        DateTimeResponse response = service.check(request);
        // Trả 200 OK dù valid hay invalid — lỗi logic không phải lỗi HTTP
        return ResponseEntity.ok(response);
    }

    /**
     * GET /api/datetime/check?day=29&month=2&year=2000
     */
    @GetMapping("/check")
    public ResponseEntity<DateTimeResponse> checkByQuery(
            @RequestParam String day,
            @RequestParam String month,
            @RequestParam String year
    ) {
        DateTimeResponse response = service.check(new DateTimeRequest(day, month, year));
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/datetime/clear
     * Stateless app nên chỉ trả thông báo clear thành công
     */
    @PostMapping("/clear")
    public ResponseEntity<DateTimeResponse> clear() {
        return ResponseEntity.ok(
            new DateTimeResponse(true, "Cleared successfully.")
        );
    }
}
