package com.example.demo.controller;

import com.example.demo.dto.CoachRequest;
import com.example.demo.dto.CoachResponse;
import com.example.demo.service.CoachService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/coaches")
@RequiredArgsConstructor
public class CoachController {

    private final CoachService coachService;

    @GetMapping
    public List<CoachResponse> findAll() {
        return coachService.findAll();
    }

    @GetMapping("/{id}")
    public CoachResponse findById(@PathVariable Long id) {
        return coachService.findById(id);
    }

    @PostMapping
    public ResponseEntity<CoachResponse> create(@RequestBody CoachRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(coachService.create(request));
    }

    @PutMapping("/{id}")
    public CoachResponse update(@PathVariable Long id, @RequestBody CoachRequest request) {
        return coachService.update(id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        coachService.delete(id);
        return ResponseEntity.noContent().build();
    }
}