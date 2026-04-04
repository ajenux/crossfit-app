package com.example.demo.controller;

import com.example.demo.dto.AthleteRequest;
import com.example.demo.dto.AthleteResponse;
import com.example.demo.service.AthleteService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/athletes")
@RequiredArgsConstructor
public class AthleteController {

    private final AthleteService athleteService;

    @GetMapping
    public List<AthleteResponse> findAll(@RequestParam(required = false) Long coachId) {
        if (coachId != null) {
            return athleteService.findByCoach(coachId);
        }
        return athleteService.findAll();
    }

    @GetMapping("/{id}")
    public AthleteResponse findById(@PathVariable Long id) {
        return athleteService.findById(id);
    }

    @PostMapping
    public ResponseEntity<AthleteResponse> create(@RequestBody AthleteRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(athleteService.create(request));
    }

    @PutMapping("/{id}")
    public AthleteResponse update(@PathVariable Long id, @RequestBody AthleteRequest request) {
        return athleteService.update(id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        athleteService.delete(id);
        return ResponseEntity.noContent().build();
    }
}