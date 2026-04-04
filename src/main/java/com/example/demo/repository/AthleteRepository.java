package com.example.demo.repository;

import com.example.demo.model.Athlete;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AthleteRepository extends JpaRepository<Athlete, Long> {
    boolean existsByEmail(String email);
    List<Athlete> findByCoachId(Long coachId);
}