package com.example.demo.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

import java.util.List;

@Getter
@AllArgsConstructor
public class AthleteDashboardResponse {
    private Long athleteId;
    private String athleteName;
    private String coachName;
    private List<WorkoutResponse> workouts;
    private List<CoachAvailabilityResponse> coachAvailability;
    private long totalWorkouts;
    private long completedWorkouts;
}
