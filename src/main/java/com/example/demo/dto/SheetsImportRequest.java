package com.example.demo.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
public class SheetsImportRequest {
    private int weekNumber;
    private Long athleteAId;
    private Long athleteBId;
    private Long coachId;
    private LocalDate startDate;
}