package com.example.demo.controller;

import com.example.demo.dto.AthleteRequest;
import com.example.demo.dto.AthleteResponse;
import com.example.demo.service.AthleteService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/athletes")
@RequiredArgsConstructor
@PreAuthorize("hasRole('COACH')")
public class AthleteController {

    private final AthleteService athleteService;

    @GetMapping
    public Page<AthleteResponse> findAll(
            @RequestParam(required = false) Long coachId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        PageRequest pageable = PageRequest.of(page, size);
        if (coachId != null) return athleteService.findByCoach(coachId, pageable);
        return athleteService.findAll(pageable);
    }

    @GetMapping("/{id}")
    public AthleteResponse findById(@PathVariable Long id) {
        return athleteService.findById(id);
    }

    @PostMapping
    public ResponseEntity<AthleteResponse> create(@Valid @RequestBody AthleteRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(athleteService.create(request));
    }

    @PutMapping("/{id}")
    public AthleteResponse update(@PathVariable Long id, @Valid @RequestBody AthleteRequest request) {
        return athleteService.update(id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        athleteService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
