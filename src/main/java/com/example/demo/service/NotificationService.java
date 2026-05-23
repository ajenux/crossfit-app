package com.example.demo.service;

import com.example.demo.dto.NotificationResponse;
import com.example.demo.model.Athlete;
import com.example.demo.model.Notification;
import com.example.demo.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;

    public void create(Athlete athlete, String message) {
        Notification n = new Notification();
        n.setAthlete(athlete);
        n.setMessage(message);
        notificationRepository.save(n);
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> getForAthlete(Long athleteId) {
        return notificationRepository.findByAthleteIdOrderByCreatedAtDesc(athleteId)
                .stream()
                .map(NotificationResponse::new)
                .toList();
    }

    public void markAllRead(Long athleteId) {
        notificationRepository.markAllReadByAthleteId(athleteId);
    }
}
