package com.example.demo.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;

@Getter
@AllArgsConstructor
public class CoachAvailabilityResponse {
    private Long id;
    private Long coachId;
    private String coachName;
    private boolean recurring;
    private DayOfWeek dayOfWeek;
    private LocalDate specificDate;
    private LocalTime startTime;
    private LocalTime endTime;
}
