package com.example.demo.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;

@Getter
@Setter
public class CoachAvailabilityRequest {
    @NotNull
    private Long coachId;
    private boolean recurring;
    private DayOfWeek dayOfWeek;    // required when recurring = true
    private LocalDate specificDate; // required when recurring = false
    @NotNull
    private LocalTime startTime;
    @NotNull
    private LocalTime endTime;
}