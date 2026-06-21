package com.example.demo.controller;

import com.example.demo.dto.AthleteDashboardResponse;
import com.example.demo.service.AthleteDashboardService;
import com.example.demo.service.AutoImportService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
public class AthleteDashboardController {

    private final AthleteDashboardService dashboardService;
    private final AutoImportService autoImportService;

    @GetMapping("/athlete/{athleteId}")
    public AthleteDashboardResponse getDashboard(@PathVariable Long athleteId) {
        // Best-effort: import current week from sheet if the athlete has no sheet workouts yet.
        // Runs synchronously so workouts are available immediately on first load of the week.
        // Never blocks or fails the dashboard — exceptions are caught inside triggerIfNeededForAthlete.
        autoImportService.triggerIfNeededForAthlete(athleteId);
        return dashboardService.getDashboard(athleteId);
    }
}
