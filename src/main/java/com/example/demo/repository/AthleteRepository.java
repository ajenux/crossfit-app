package com.example.demo.repository;

import com.example.demo.model.Athlete;
import com.example.demo.model.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface AthleteRepository extends JpaRepository<Athlete, Long> {
    boolean existsByEmail(String email);
    Page<Athlete> findByCoachId(Long coachId, Pageable pageable);
    Optional<Athlete> findByEmail(String email);
    Optional<Athlete> findByUser(User user);
}