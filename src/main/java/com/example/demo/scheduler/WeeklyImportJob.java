package com.example.demo.scheduler;

import com.example.demo.dto.SheetsImportRequest;
import com.example.demo.model.ImportAthleteConfig;
import com.example.demo.model.ImportConfig;
import com.example.demo.repository.ImportConfigRepository;
import com.example.demo.service.GoogleSheetsService;
import com.example.demo.service.SheetsImportService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Component
@RequiredArgsConstructor
@Slf4j
public class WeeklyImportJob {

    private final ImportConfigRepository importConfigRepository;
    private final SheetsImportService sheetsImportService;
    private final GoogleSheetsService googleSheetsService;

    // Mirrors the _monthMap in Flutter to match sheet tab names to month numbers.
    private static final Map<String, Integer> MONTH_TAB_MAP = new HashMap<>();
    static {
        MONTH_TAB_MAP.put("enero", 1);
        MONTH_TAB_MAP.put("feb", 2);   MONTH_TAB_MAP.put("febrero", 2);
        MONTH_TAB_MAP.put("mar", 3);   MONTH_TAB_MAP.put("marzo", 3);   MONTH_TAB_MAP.put("marz", 3);
        MONTH_TAB_MAP.put("abr", 4);   MONTH_TAB_MAP.put("abril", 4);   MONTH_TAB_MAP.put("abri", 4);
        MONTH_TAB_MAP.put("may", 5);   MONTH_TAB_MAP.put("mayo", 5);    MONTH_TAB_MAP.put("maio", 5);
        MONTH_TAB_MAP.put("jun", 6);   MONTH_TAB_MAP.put("junio", 6);
        MONTH_TAB_MAP.put("jul", 7);   MONTH_TAB_MAP.put("julio", 7);
        MONTH_TAB_MAP.put("ago", 8);   MONTH_TAB_MAP.put("agosto", 8);  MONTH_TAB_MAP.put("agost", 8);
        MONTH_TAB_MAP.put("sep", 9);   MONTH_TAB_MAP.put("sept", 9);    MONTH_TAB_MAP.put("septiembre", 9);
        MONTH_TAB_MAP.put("oct", 10);  MONTH_TAB_MAP.put("octu", 10);   MONTH_TAB_MAP.put("octubre", 10);
        MONTH_TAB_MAP.put("nov", 11);  MONTH_TAB_MAP.put("noviembre", 11);
        MONTH_TAB_MAP.put("dic", 12);  MONTH_TAB_MAP.put("diciembre", 12);
    }

    // Runs every day at 06:00. The lastImportedMonday field prevents re-importing the same week.
    // This means if the Monday run fails (sheet not ready yet), Tuesday will retry automatically.
    @Scheduled(cron = "0 0 6 * * *")
    @Transactional
    public void run() {
        List<ImportConfig> configs = importConfigRepository.findAllByEnabledTrue();
        if (configs.isEmpty()) return;

        LocalDate currentMonday = LocalDate.now().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));

        for (ImportConfig config : configs) {
            if (currentMonday.equals(config.getLastImportedMonday())) {
                log.debug("Auto-import: week {} already imported for coach {}", currentMonday, config.getCoachId());
                continue;
            }
            tryImport(config, currentMonday);
        }
    }

    private void tryImport(ImportConfig config, LocalDate currentMonday) {
        try {
            List<String> tabs = googleSheetsService.getSheetNames();
            Optional<String> tab = tabs.stream()
                    .filter(t -> MONTH_TAB_MAP.getOrDefault(t.toLowerCase().trim(), -1)
                            == currentMonday.getMonthValue())
                    .reduce((first, second) -> second);

            if (tab.isEmpty()) {
                log.warn("Auto-import: no sheet tab found for month {} (coach {})",
                        currentMonday.getMonth(), config.getCoachId());
                return;
            }

            int weekNumber = weekNumberInMonth(currentMonday);

            SheetsImportRequest req = new SheetsImportRequest();
            req.setSheetName(tab.get());
            req.setWeekNumber(weekNumber);
            req.setCoachId(config.getCoachId());
            req.setStartDate(currentMonday);
            req.setTrainingDays(config.getTrainingDays().isEmpty() ? null : config.getTrainingDays());
            req.setAthletes(config.getAthletes().stream()
                    .map(this::toAthleteImport)
                    .toList());

            var result = sheetsImportService.importWeek(req);
            config.setLastImportedMonday(currentMonday);
            importConfigRepository.save(config);

            log.info("Auto-import: {} workouts created for week {} (coach {})",
                    result.workoutsCreated(), weekNumber, config.getCoachId());

        } catch (Exception e) {
            log.error("Auto-import failed for coach {}: {}", config.getCoachId(), e.getMessage(), e);
        }
    }

    // Returns the 1-based week number of [monday] within its month.
    private int weekNumberInMonth(LocalDate monday) {
        LocalDate firstOfMonth = monday.withDayOfMonth(1);
        int daysToFirstMonday = (DayOfWeek.MONDAY.getValue() - firstOfMonth.getDayOfWeek().getValue() + 7) % 7;
        LocalDate firstMonday = firstOfMonth.plusDays(daysToFirstMonday);
        return (int) ((monday.toEpochDay() - firstMonday.toEpochDay()) / 7) + 1;
    }

    private SheetsImportRequest.AthleteImport toAthleteImport(ImportAthleteConfig a) {
        SheetsImportRequest.AthleteImport ai = new SheetsImportRequest.AthleteImport();
        ai.setAthleteId(a.getAthleteId());
        ai.setWeightIndex(a.getWeightIndex());
        return ai;
    }
}