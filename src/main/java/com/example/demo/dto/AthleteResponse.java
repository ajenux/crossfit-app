package com.example.demo.dto;

import com.example.demo.model.Athlete;
import lombok.Getter;

@Getter
public class AthleteResponse {
    private final Long id;
    private final String name;
    private final String email;
    private final Long coachId;
    private final String coachName;

    public AthleteResponse(Athlete athlete) {
        this.id = athlete.getId();
        this.name = athlete.getName();
        this.email = athlete.getEmail();
        this.coachId = athlete.getCoach() != null ? athlete.getCoach().getId() : null;
        this.coachName = athlete.getCoach() != null ? athlete.getCoach().getName() : null;
    }
}