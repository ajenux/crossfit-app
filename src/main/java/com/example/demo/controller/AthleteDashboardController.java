package com.example.demo.controller;

import com.example.demo.dto.AthleteDashboardResponse;
import com.example.demo.service.AthleteDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
public class AthleteDashboardController {

    private final AthleteDashboardService dashboardService;

    @GetMapping("/athlete/{athleteId}")
    public AthleteDashboardResponse getDashboard(@PathVariable Long athleteId) {
        return dashboardService.getDashboard(athleteId);
    }
}
