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

            // Week numbers cannot be reliably derived from calendar math — the sheet's own
            // "Semana N" numbering does not necessarily align with calendar weeks. Once a
            // human has confirmed one week's mapping (the anchor), every other week in the
            // same tab is a fixed 7-day offset from it, so the rest can be backfilled safely.
            if (tab.get().equals(config.getLastImportedTab()) && config.getLastImportedWeekNumber() != null) {
                backfillDueWeeks(config, tab.get(), config.getLastImportedWeekNumber(),
                        config.getLastImportedMonday(), monday);
            } else {
                String context = config.getLastImportedTab() == null
                        ? "no prior import found"
                        : "previous tab was '" + config.getLastImportedTab() + "'";
                String msg = "New sheet tab '" + tab.get() + "' (" + context
                        + ") — import this week manually once from the Import tab to confirm the starting week; "
                        + "auto-import will then backfill everything due and continue on its own.";
                log.warn("Auto-import: {} (coach {})", msg, config.getCoachId());
                importConfigService.recordFailure(config.getId(), msg);
            }

        } catch (Exception e) {
            log.error("Auto-import failed for coach {}: {}", config.getCoachId(), e.getMessage(), e);
            importConfigService.recordFailure(config.getId(), e.getMessage());
        }
    }

    /**
     * Imports every week in [tab] whose calendar Monday — derived from the anchor via simple
     * week-offset arithmetic, since the sheet's week blocks are always sequential 7-day chunks —
     * falls on or before [targetMonday]. Used both for week-to-week catch-up and to backfill the
     * rest of a tab right after a coach confirms one week's mapping (manually or automatically).
     */
    public void backfillDueWeeks(ImportConfig config, String tab, int anchorWeekNumber,
                                  LocalDate anchorMonday, LocalDate targetMonday) {
        try {
            List<GoogleSheetsService.ParsedWeek> weeks = sheetsImportService.listWeeks(tab);
            int latestDueWeekNumber = anchorWeekNumber;
            LocalDate latestDueMonday = anchorMonday;

            for (GoogleSheetsService.ParsedWeek week : weeks) {
                LocalDate weekMonday = anchorMonday.plusWeeks(week.weekNumber() - anchorWeekNumber);
                if (weekMonday.isAfter(targetMonday)) continue; // not due yet

                SheetsImportRequest req = buildRequest(config, tab, weekMonday, week.weekNumber());
                sheetsImportService.importWeek(req);

                if (!weekMonday.isBefore(latestDueMonday)) {
                    latestDueMonday = weekMonday;
                    latestDueWeekNumber = week.weekNumber();
                }
            }

            importConfigService.recordSuccess(config.getId(), latestDueMonday, tab, latestDueWeekNumber);
            log.info("Auto-import: tab '{}' backfilled through week {} ({}) for coach {}",
                    tab, latestDueWeekNumber, latestDueMonday, config.getCoachId());
        } catch (Exception e) {
            log.error("Auto-import: backfill failed for tab '{}' (coach {}): {}",
                    tab, config.getCoachId(), e.getMessage(), e);
            importConfigService.recordFailure(config.getId(), "Backfill failed: " + e.getMessage());
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

    private SheetsImportRequest buildRequest(ImportConfig config, String tab, LocalDate monday, int weekNumber) {
        SheetsImportRequest req = new SheetsImportRequest();
        req.setSheetName(tab);
        req.setWeekNumber(weekNumber);
        req.setCoachId(config.getCoachId());
        req.setStartDate(monday);
        req.setTrainingDays(config.getTrainingDays().isEmpty() ? null : config.getTrainingDays());
        req.setAthletes(config.getAthletes().stream()
                .map(this::toAthleteImport)
                .toList());
        return req;
    }

    private SheetsImportRequest.AthleteImport toAthleteImport(ImportAthleteConfig a) {
        SheetsImportRequest.AthleteImport ai = new SheetsImportRequest.AthleteImport();
        ai.setAthleteId(a.getAthleteId());
        ai.setWeightIndex(a.getWeightIndex());
        return ai;
    }
}
