package com.example.demo.controller;

import com.example.demo.dto.ImportConfigRequest;
import com.example.demo.dto.ImportConfigResponse;
import com.example.demo.service.ImportConfigService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/import-config")
@RequiredArgsConstructor
public class ImportConfigController {

    private final ImportConfigService importConfigService;

    @GetMapping("/{coachId}")
    @PreAuthorize("hasRole('COACH')")
    public ResponseEntity<ImportConfigResponse> get(@PathVariable Long coachId) {
        return importConfigService.findByCoach(coachId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping
    @PreAuthorize("hasRole('COACH')")
    public ImportConfigResponse save(@Valid @RequestBody ImportConfigRequest request) {
        return importConfigService.save(request);
    }
}