package com.example.demo.controller;

import com.example.demo.dto.NotificationResponse;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.security.SecurityUtils;
import com.example.demo.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;
    private final AthleteRepository athleteRepository;

    @GetMapping
    @PreAuthorize("hasRole('ATHLETE')")
    public ResponseEntity<List<NotificationResponse>> getNotifications() {
        return ResponseEntity.ok(notificationService.getForAthlete(currentAthleteId()));
    }

    @PutMapping("/read")
    @PreAuthorize("hasRole('ATHLETE')")
    public ResponseEntity<Void> markAllRead() {
        notificationService.markAllRead(currentAthleteId());
        return ResponseEntity.noContent().build();
    }

    private Long currentAthleteId() {
        String email = SecurityUtils.getCurrentUserEmail();
        return athleteRepository.findByEmail(email)
                .map(athlete -> athlete.getId())
                .orElseThrow(() -> new RuntimeException("Athlete profile not found"));
    }
}
