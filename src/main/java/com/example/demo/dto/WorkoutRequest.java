package com.example.demo.dto;

import com.example.demo.model.WorkoutType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
public class WorkoutRequest {
    @NotBlank @Size(max = 200)
    private String name;
    @Size(max = 2000)
    private String description;
    @NotNull
    private WorkoutType type;
    @NotNull
    private LocalDate scheduledDate;
    @NotNull
    private Long athleteId;
    @NotNull
    private Long coachId;
}