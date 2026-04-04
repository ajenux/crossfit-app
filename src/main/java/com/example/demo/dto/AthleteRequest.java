package com.example.demo.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AthleteRequest {
    private String name;
    private String email;
    private Long coachId;
}