package com.example.demo.repository;

import com.example.demo.model.CoachAvailability;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CoachAvailabilityRepository extends JpaRepository<CoachAvailability, Long> {
    List<CoachAvailability> findByCoachId(Long coachId);
}
