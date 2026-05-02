package com.example.demo.repository;

import com.example.demo.model.Coach;
import com.example.demo.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CoachRepository extends JpaRepository<Coach, Long> {
    boolean existsByEmail(String email);
    Optional<Coach> findByEmail(String email);
    Optional<Coach> findByUser(User user);
}