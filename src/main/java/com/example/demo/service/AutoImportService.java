package com.example.demo.service;

import com.example.demo.dto.SheetsImportRequest;
import com.example.demo.model.ImportAthleteConfig;
import com.example.demo.model.ImportConfig;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.ImportConfigRepository;
import com.example.demo.repository.WorkoutRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
@Slf4j
@RequiredArgsConstructor
public class AutoImportService {

    private final ImportConfigRepository importConfigRepository;
    private final WorkoutRepository workoutRepository;
    private final AthleteRepository athleteRepository;
    private final SheetsImportService sheetsImportService;
    private final ImportConfigService importConfigService;
    private final GoogleSheetsService googleSheetsService;

    private static final Map<String, Integer> MONTH_TAB_MAP = new HashMap<>();
    static {
        MONTH_TAB_MAP.put("enero",     1);
        MONTH_TAB_MAP.put("feb",       2); MONTH_TAB_MAP.put("febrero",    2);
        MONTH_TAB_MAP.put("mar",       3); MONTH_TAB_MAP.put("marzo",      3); MONTH_TAB_MAP.put("marz",      3);
        MONTH_TAB_MAP.put("abr",       4); MONTH_TAB_MAP.put("abril",      4); MONTH_TAB_MAP.put("abri",      4);
        MONTH_TAB_MAP.put("may",       5); MONTH_TAB_MAP.put("mayo",       5); MONTH_TAB_MAP.put("maio",      5);
        MONTH_TAB_MAP.put("jun",       6); MONTH_TAB_MAP.put("junio",      6);
        MONTH_TAB_MAP.put("jul",       7); MONTH_TAB_MAP.put("julio",      7);
        MONTH_TAB_MAP.put("ago",       8); MONTH_TAB_MAP.put("agosto",     8); MONTH_TAB_MAP.put("agost",     8);
        MONTH_TAB_MAP.put("sep",       9); MONTH_TAB_MAP.put("sept",       9); MONTH_TAB_MAP.put("septiembre",9);
        MONTH_TAB_MAP.put("oct",      10); MONTH_TAB_MAP.put("octu",      10); MONTH_TAB_MAP.put("octubre",  10);
        MONTH_TAB_MAP.put("nov",      11); MONTH_TAB_MAP.put("noviembre", 11);
        MONTH_TAB_MAP.put("dic",      12); MONTH_TAB_MAP.put("diciembre", 12);
    }

    /**
     * Called by the scheduler. Runs for every enabled ImportConfig.
     */
    public void runAll() {
        LocalDate monday = LocalDate.now().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        List<ImportConfig> configs = importConfigRepository.findAllByEnabledTrue();

        if (configs.isEmpty()) {
            log.warn("Auto-import: no enabled ImportConfig found — skipping");
            return;
        }

        log.info("Auto-import: running for {} config(s), week of {}", configs.size(), monday);
        for (ImportConfig config : configs) {
            runForConfig(config, monday);
        }
    }

    /**
     * Called from the athlete dashboard. Imports the current week only if the athlete
     * has no sheet-imported workouts yet this week. Never propagates exceptions — the
     * dashboard must load even if the sheet is temporarily unavailable.
     */
    public void triggerIfNeededForAthlete(Long athleteId) {
        try {
            var athlete = athleteRepository.findById(athleteId).orElse(null);
            if (athlete == null || athlete.getCoach() == null) return;

            var config = importConfigRepository.findByCoachId(athlete.getCoach().getId()).orElse(null);
            if (config == null || !config.isEnabled()) return;

            LocalDate monday = LocalDate.now().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
            LocalDate sunday = monday.plusDays(6);

            boolean alreadyImported = workoutRepository
                    .existsByAthleteIdAndScheduledDateBetweenAndSheetsSourceKeyIsNotNull(athleteId, monday, sunday);
            if (alreadyImported) return;

            log.info("Auto-import: athlete {} has no sheet workouts for week {} — importing now", athleteId, monday);
            runForConfig(config, monday);

        } catch (Exception e) {
            log.error("Auto-import triggered from dashboard failed for athlete {}: {}", athleteId, e.getMessage(), e);
        }
    }

    /**
     * Core import logic for a single coach config and a given week (Monday date).
     * Finds the correct sheet tab, builds the request, delegates to SheetsImportService,
     * and records success or failure on the config.
     */
    public void runForConfig(ImportConfig config, LocalDate monday) {
        try {
            List<String> tabs = googleSheetsService.getSheetNames();
            log.info("Auto-import: sheet tabs {} — looking for month {} (coach {})",
                    tabs, monday.getMonth(), config.getCoachId());

            Optional<String> tab = resolveTab(tabs, monday.getMonthValue());
            if (tab.isEmpty()) {
                String msg = "No sheet tab found for month " + monday.getMonth()
                        + ". Available tabs: " + tabs;
                log.warn("Auto-import: {} (coach {})", msg, config.getCoachId());
                importConfigService.recordFailure(config.getId(), msg);
                return;
            }

            log.info("Auto-import: matched tab '{}' for month {} (coach {})",
                    tab.get(), monday.getMonth(), config.getCoachId());

            SheetsImportRequest req = buildRequest(config, tab.get(), monday);
            var result = sheetsImportService.importWeek(req);

            importConfigService.recordSuccess(config.getId(), monday);
            log.info("Auto-import: {} workout(s) processed for week {} tab '{}' (coach {})",
                    result.workoutsCreated(), req.getWeekNumber(), tab.get(), config.getCoachId());

        } catch (Exception e) {
            log.error("Auto-import failed for coach {}: {}", config.getCoachId(), e.getMessage(), e);
            importConfigService.recordFailure(config.getId(), e.getMessage());
        }
    }

    // Finds the last tab whose name starts with a keyword matching targetMonth.
    // "Last" handles cases where the coach keeps old tabs (e.g., "mayo viejo" + "mayo").
    private Optional<String> resolveTab(List<String> tabs, int targetMonth) {
        return tabs.stream()
                .filter(t -> {
                    String lower = t.toLowerCase().trim();
                    return MONTH_TAB_MAP.entrySet().stream()
                            .anyMatch(e -> lower.startsWith(e.getKey()) && e.getValue() == targetMonth);
                })
                .reduce((first, second) -> second);
    }

    private SheetsImportRequest buildRequest(ImportConfig config, String tab, LocalDate monday) {
        SheetsImportRequest req = new SheetsImportRequest();
        req.setSheetName(tab);
        req.setWeekNumber(weekNumberInMonth(monday));
        req.setCoachId(config.getCoachId());
        req.setStartDate(monday);
        req.setTrainingDays(config.getTrainingDays().isEmpty() ? null : config.getTrainingDays());
        req.setAthletes(config.getAthletes().stream()
                .map(this::toAthleteImport)
                .toList());
        return req;
    }

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
