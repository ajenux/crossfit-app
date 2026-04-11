package com.example.demo.controller;

import com.example.demo.dto.CoachAvailabilityRequest;
import com.example.demo.dto.CoachAvailabilityResponse;
import com.example.demo.service.CoachAvailabilityService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/availability")
@RequiredArgsConstructor
public class CoachAvailabilityController {

    private final CoachAvailabilityService availabilityService;

    // Coach sets their availability
    @PostMapping
    public ResponseEntity<CoachAvailabilityResponse> create(@RequestBody CoachAvailabilityRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(availabilityService.create(request));
    }

    // View availability for a specific coach (used by both coaches and athletes)
    @GetMapping("/coach/{coachId}")
    public List<CoachAvailabilityResponse> findByCoach(@PathVariable Long coachId) {
        return availabilityService.findByCoach(coachId);
    }

    // Coach deletes an availability slot
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        availabilityService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
