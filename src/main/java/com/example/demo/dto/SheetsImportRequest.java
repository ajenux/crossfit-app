package com.example.demo.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;

@Getter
@Setter
public class SheetsImportRequest {
    @NotBlank
    private String sheetName;
    @Min(1)
    private int weekNumber;
    @NotNull
    private Long coachId;
    @NotNull
    private LocalDate startDate;
    @NotEmpty
    private List<AthleteImport> athletes;

    // Optional: maps Dia N to a specific weekday. If null, falls back to consecutive days from startDate.
    private List<DayOfWeek> trainingDays;

    @Getter
    @Setter
    public static class AthleteImport {
        @NotNull
        private Long athleteId;
        @Min(0) @Max(1)
        private int weightIndex; // 0 = first weight in (X/Y), 1 = second weight
    }
}