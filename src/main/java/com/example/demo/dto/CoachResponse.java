package com.example.demo.dto;

import com.example.demo.model.Coach;
import lombok.Getter;

@Getter
public class CoachResponse {
    private final Long id;
    private final String name;
    private final String email;
    private final int athleteCount;

    public CoachResponse(Coach coach) {
        this.id = coach.getId();
        this.name = coach.getName();
        this.email = coach.getEmail();
        this.athleteCount = coach.getAthletes().size();
    }
}