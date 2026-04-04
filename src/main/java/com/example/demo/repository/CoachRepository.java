package com.example.demo.repository;

import com.example.demo.model.Coach;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CoachRepository extends JpaRepository<Coach, Long> {
    boolean existsByEmail(String email);
}