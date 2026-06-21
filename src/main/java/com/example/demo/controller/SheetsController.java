package com.example.demo.controller;

import com.example.demo.dto.SheetsImportRequest;
import com.example.demo.dto.SheetsImportResponse;
import com.example.demo.dto.WeekPreviewResponse;
import com.example.demo.service.AutoImportService;
import com.example.demo.service.SheetsImportService;
import lombok.RequiredArgsConstructor;
import jakarta.validation.Valid;
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
    private final AutoImportService autoImportService;

    @GetMapping("/tabs")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<List<String>> getSheetTabs() throws IOException, GeneralSecurityException {
        return ResponseEntity.ok(sheetsImportService.getSheetNames());
    }

    @GetMapping("/weeks")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<List<WeekPreviewResponse>> listWeeks(
            @RequestParam String sheet) throws IOException, GeneralSecurityException {
        List<WeekPreviewResponse> weeks = sheetsImportService.listWeeks(sheet).stream()
                .map(w -> new WeekPreviewResponse(w.weekNumber(), w.dayCount()))
                .toList();
        return ResponseEntity.ok(weeks);
    }

    @PostMapping("/import")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<SheetsImportResponse> importWeek(@Valid @RequestBody SheetsImportRequest request)
            throws IOException, GeneralSecurityException {
        return ResponseEntity.ok(sheetsImportService.importWeek(request));
    }

    @PostMapping("/auto-import/run")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<String> triggerAutoImport() {
        autoImportService.runAll();
        return ResponseEntity.ok("Auto-import triggered — check /api/import-config/{coachId} for status");
    }
}