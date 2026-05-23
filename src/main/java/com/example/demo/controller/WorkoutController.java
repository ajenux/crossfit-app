package com.example.demo.controller;

import com.example.demo.dto.WorkoutRequest;
import com.example.demo.dto.WorkoutResponse;
import com.example.demo.service.WorkoutService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/workouts")
@RequiredArgsConstructor
public class WorkoutController {

    private final WorkoutService workoutService;

    @GetMapping
    public Page<WorkoutResponse> findAll(
            @RequestParam(required = false) Long athleteId,
            @RequestParam(required = false) Long coachId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        PageRequest pageable = PageRequest.of(page, size);
        if (athleteId != null) return workoutService.findByAthlete(athleteId, pageable);
        if (coachId != null) return workoutService.findByCoach(coachId, pageable);
        return workoutService.findAll(pageable);
    }

    @GetMapping("/{id}")
    public WorkoutResponse findById(@PathVariable Long id) {
        return workoutService.findById(id);
    }

    @PostMapping
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<WorkoutResponse> create(@Valid @RequestBody WorkoutRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(workoutService.create(request));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('COACH')")
    public WorkoutResponse update(@PathVariable Long id, @Valid @RequestBody WorkoutRequest request) {
        return workoutService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        workoutService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
