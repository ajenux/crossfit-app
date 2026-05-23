package com.example.demo.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AthleteRequest {
    @NotBlank @Size(max = 100)
    private String name;
    @NotBlank @Email
    private String email;
    private Long coachId;
}
