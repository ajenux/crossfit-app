package com.example.demo.repository;

import com.example.demo.model.Workout;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkoutRepository extends JpaRepository<Workout, Long> {
    Page<Workout> findByAthleteId(Long athleteId, Pageable pageable);
    Page<Workout> findByCoachId(Long coachId, Pageable pageable);
    void deleteAllByCoachId(Long coachId);
}