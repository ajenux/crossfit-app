package com.example.demo.repository;

import com.example.demo.model.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    List<Notification> findByAthleteIdOrderByCreatedAtDesc(Long athleteId);

    long countByAthleteIdAndReadFalse(Long athleteId);

    @Modifying
    @Query("UPDATE Notification n SET n.read = true WHERE n.athlete.id = :athleteId")
    void markAllReadByAthleteId(@Param("athleteId") Long athleteId);
}
