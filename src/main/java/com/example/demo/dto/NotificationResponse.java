package com.example.demo.dto;

import com.example.demo.model.Notification;

import java.time.LocalDateTime;

public record NotificationResponse(Long id, String message, boolean read, LocalDateTime createdAt) {

    public NotificationResponse(Notification n) {
        this(n.getId(), n.getMessage(), n.isRead(), n.getCreatedAt());
    }
}
