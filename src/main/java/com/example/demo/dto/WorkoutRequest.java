package com.example.demo.dto;

import com.example.demo.model.WorkoutType;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
public class WorkoutRequest {
    private String name;
    private String description;
    private WorkoutType type;
    private LocalDate scheduledDate;
    private Long athleteId;
    private Long coachId;
}