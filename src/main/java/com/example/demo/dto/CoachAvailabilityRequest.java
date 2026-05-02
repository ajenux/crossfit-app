package com.example.demo.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;

@Getter
@Setter
public class CoachAvailabilityRequest {
    private Long coachId;
    private boolean recurring;
    private DayOfWeek dayOfWeek;       // required if recurring = true
    private LocalDate specificDate;    // required if recurring = false
    private LocalTime startTime;
    private LocalTime endTime;
}
