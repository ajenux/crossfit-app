package com.example.demo.controller;

import com.example.demo.dto.CoachRequest;
import com.example.demo.dto.CoachResponse;
import com.example.demo.service.CoachService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/coaches")
@RequiredArgsConstructor
public class CoachController {

    private final CoachService coachService;

    @GetMapping
    public Page<CoachResponse> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return coachService.findAll(PageRequest.of(page, size));
    }

    @GetMapping("/{id}")
    public CoachResponse findById(@PathVariable Long id) {
        return coachService.findById(id);
    }

    @PostMapping
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<CoachResponse> create(@RequestBody CoachRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(coachService.create(request));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('COACH')")
    public CoachResponse update(@PathVariable Long id, @RequestBody CoachRequest request) {
        return coachService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        coachService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
