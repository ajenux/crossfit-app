package com.example.demo.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.time.DayOfWeek;
import java.util.List;

@Getter
@Setter
public class ImportConfigRequest {
    @NotNull
    private Long coachId;
    private boolean enabled;
    @NotNull
    private List<AthleteEntry> athletes;
    private List<DayOfWeek> trainingDays;

    @Getter
    @Setter
    public static class AthleteEntry {
        @NotNull
        private Long athleteId;
        private int weightIndex;
    }
}