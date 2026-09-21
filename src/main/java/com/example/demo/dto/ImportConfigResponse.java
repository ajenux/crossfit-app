package com.example.demo.dto;

import com.example.demo.model.ImportAthleteConfig;
import com.example.demo.model.ImportConfig;
import lombok.Getter;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Getter
public class ImportConfigResponse {
    private final Long coachId;
    private final boolean enabled;
    private final LocalDate lastImportedMonday;
    private final LocalDateTime lastAttemptAt;
    private final LocalDateTime lastSuccessAt;
    private final String lastError;
    private final List<AthleteEntry> athletes;
    private final List<DayOfWeek> trainingDays;

    public ImportConfigResponse(ImportConfig c) {
        this.coachId = c.getCoachId();
        this.enabled = c.isEnabled();
        this.lastImportedMonday = c.getLastImportedMonday();
        this.lastAttemptAt = c.getLastAttemptAt();
        this.lastSuccessAt = c.getLastSuccessAt();
        this.lastError = c.getLastError();
        this.athletes = c.getAthletes().stream()
                .map(a -> new AthleteEntry(a.getAthleteId(), a.getWeightIndex()))
                .toList();
        this.trainingDays = c.getTrainingDays();
    }

    @Getter
    public static class AthleteEntry {
        private final Long athleteId;
        private final int weightIndex;
        AthleteEntry(Long athleteId, int weightIndex) {
            this.athleteId = athleteId;
            this.weightIndex = weightIndex;
        }
    }
}