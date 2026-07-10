package com.example.demo.controller;

import com.example.demo.dto.SheetsImportRequest;
import com.example.demo.dto.SheetsImportResponse;
import com.example.demo.dto.WeekPreviewResponse;
import com.example.demo.service.AutoImportService;
import com.example.demo.service.ImportConfigService;
import com.example.demo.service.SheetsImportService;
import lombok.RequiredArgsConstructor;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.List;

@RestController
@RequestMapping("/api/sheets")
@RequiredArgsConstructor
public class SheetsController {

    private final SheetsImportService sheetsImportService;
    private final AutoImportService autoImportService;
    private final ImportConfigService importConfigService;

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
                .map(w -> new WeekPreviewResponse(w.weekNumber(), w.label(), w.dayCount()))
                .toList();
        return ResponseEntity.ok(weeks);
    }

    @PostMapping("/import")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<SheetsImportResponse> importWeek(@Valid @RequestBody SheetsImportRequest request)
            throws IOException, GeneralSecurityException {
        SheetsImportResponse response = sheetsImportService.importWeek(request);

        // If this import confirms/advances the coach's current week, use it as the anchor and
        // backfill every other due week in the same tab (past and present) — a coach shouldn't
        // have to click through each week individually once one mapping is confirmed. A manual
        // touch-up of an already-past week (data cleanup) does not move the anchor.
        importConfigService.findConfigEntity(request.getCoachId()).ifPresent(config -> {
            LocalDate lastMonday = config.getLastImportedMonday();
            boolean isAdvancing = lastMonday == null || !request.getStartDate().isBefore(lastMonday);
            if (isAdvancing) {
                LocalDate today = LocalDate.now().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
                autoImportService.backfillDueWeeks(config, request.getSheetName(), request.getWeekNumber(),
                        request.getStartDate(), today);
            }
        });

        return ResponseEntity.ok(response);
    }

    @PostMapping("/auto-import/run")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<String> triggerAutoImport() {
        autoImportService.runAll();
        return ResponseEntity.ok("Auto-import triggered — check /api/import-config/{coachId} for status");
    }
}