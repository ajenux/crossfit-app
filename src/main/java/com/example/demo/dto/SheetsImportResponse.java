package com.example.demo.dto;

import java.util.List;

public record SheetsImportResponse(int weekNumber, int workoutsCreated, List<String> workoutNames) {}