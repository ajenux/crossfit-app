package com.example.demo.scheduler;

import com.example.demo.service.AutoImportService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class WeeklyImportJob {

    private final AutoImportService autoImportService;

    // Runs 4 times a day. With idempotency in SheetsImportService, re-runs are safe.
    // If the 6am run fails (sheet not ready, API down), the 10am run will catch it automatically.
    @Scheduled(cron = "0 0 6,10,14,18 * * *")
    public void run() {
        log.info("Auto-import: scheduled run triggered");
        autoImportService.runAll();
    }
}
