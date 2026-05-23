package com.example.demo.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;
import java.util.List;

@Getter
@Setter
public class SheetsImportRequest {
    private int weekNumber;
    private Long coachId;
    private LocalDate startDate;
    private List<AthleteImport> athletes;

    @Getter
    @Setter
    public static class AthleteImport {
        private Long athleteId;
        private int weightIndex; // 0 = first weight in (X/Y), 1 = second weight
    }
}
