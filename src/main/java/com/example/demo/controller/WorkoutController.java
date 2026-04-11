package com.example.demo.controller;

import com.example.demo.dto.WorkoutRequest;
import com.example.demo.dto.WorkoutResponse;
import com.example.demo.service.WorkoutService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/workouts")
@RequiredArgsConstructor
public class WorkoutController {

    private final WorkoutService workoutService;

    @GetMapping
    public List<WorkoutResponse> findAll(
            @RequestParam(required = false) Long athleteId,
            @RequestParam(required = false) Long coachId) {
        if (athleteId != null) return workoutService.findByAthlete(athleteId);
        if (coachId != null) return workoutService.findByCoach(coachId);
        return workoutService.findAll();
    }

    @GetMapping("/{id}")
    public WorkoutResponse findById(@PathVariable Long id) {
        return workoutService.findById(id);
    }

    @PostMapping
    public ResponseEntity<WorkoutResponse> create(@RequestBody WorkoutRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(workoutService.create(request));
    }

    @PutMapping("/{id}")
    public WorkoutResponse update(@PathVariable Long id, @RequestBody WorkoutRequest request) {
        return workoutService.update(id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        workoutService.delete(id);
        return ResponseEntity.noContent().build();
    }
}