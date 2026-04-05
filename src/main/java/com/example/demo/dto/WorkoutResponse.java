package com.example.demo.dto;

import com.example.demo.model.Workout;
import com.example.demo.model.WorkoutType;
import lombok.Getter;

import java.time.LocalDate;

@Getter
public class WorkoutResponse {
    private final Long id;
    private final String name;
    private final String description;
    private final WorkoutType type;
    private final LocalDate scheduledDate;
    private final Long athleteId;
    private final String athleteName;
    private final Long coachId;
    private final String coachName;

    public WorkoutResponse(Workout workout) {
        this.id = workout.getId();
        this.name = workout.getName();
        this.description = workout.getDescription();
        this.type = workout.getType();
        this.scheduledDate = workout.getScheduledDate();
        this.athleteId = workout.getAthlete().getId();
        this.athleteName = workout.getAthlete().getName();
        this.coachId = workout.getCoach().getId();
        this.coachName = workout.getCoach().getName();
    }
}