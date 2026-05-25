package com.example.demo.repository;

import com.example.demo.model.ImportConfig;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ImportConfigRepository extends JpaRepository<ImportConfig, Long> {
    Optional<ImportConfig> findByCoachId(Long coachId);
    List<ImportConfig> findAllByEnabledTrue();
}
