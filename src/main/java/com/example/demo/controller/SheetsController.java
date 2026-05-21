package com.example.demo.controller;

import com.example.demo.dto.SheetsImportRequest;
import com.example.demo.dto.SheetsImportResponse;
import com.example.demo.dto.WeekPreviewResponse;
import com.example.demo.service.SheetsImportService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.List;

@RestController
@RequestMapping("/api/sheets")
@RequiredArgsConstructor
public class SheetsController {

    private final SheetsImportService sheetsImportService;

    @GetMapping("/weeks")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<List<WeekPreviewResponse>> listWeeks() throws IOException, GeneralSecurityException {
        List<WeekPreviewResponse> weeks = sheetsImportService.listWeeks().stream()
                .map(w -> new WeekPreviewResponse(w.weekNumber(), w.dayCount()))
                .toList();
        return ResponseEntity.ok(weeks);
    }

    @PostMapping("/import")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<SheetsImportResponse> importWeek(@RequestBody SheetsImportRequest request)
            throws IOException, GeneralSecurityException {
        return ResponseEntity.ok(sheetsImportService.importWeek(request));
    }
}