package com.example.demo.controller;

import com.example.demo.dto.CoachAvailabilityRequest;
import com.example.demo.dto.CoachAvailabilityResponse;
import com.example.demo.service.CoachAvailabilityService;
import lombok.RequiredArgsConstructor;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/availability")
@RequiredArgsConstructor
public class CoachAvailabilityController {

    private final CoachAvailabilityService availabilityService;

    @PostMapping
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<CoachAvailabilityResponse> create(@Valid @RequestBody CoachAvailabilityRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(availabilityService.create(request));
    }

    @GetMapping("/coach/{coachId}")
    public List<CoachAvailabilityResponse> findByCoach(@PathVariable Long coachId) {
        return availabilityService.findByCoach(coachId);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        availabilityService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
