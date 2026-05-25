package com.example.demo.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Embeddable
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ImportAthleteConfig {
    @Column(name = "athlete_id")
    private Long athleteId;

    @Column(name = "weight_index")
    private int weightIndex;
}