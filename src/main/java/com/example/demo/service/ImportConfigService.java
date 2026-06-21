package com.example.demo.service;

import com.example.demo.dto.ImportConfigRequest;
import com.example.demo.dto.ImportConfigResponse;
import com.example.demo.model.ImportAthleteConfig;
import com.example.demo.model.ImportConfig;
import com.example.demo.repository.ImportConfigRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
@Transactional
@RequiredArgsConstructor
public class ImportConfigService {

    private final ImportConfigRepository importConfigRepository;

    @Transactional(readOnly = true)
    public Optional<ImportConfigResponse> findByCoach(Long coachId) {
        return importConfigRepository.findByCoachId(coachId).map(ImportConfigResponse::new);
    }

    public ImportConfigResponse save(ImportConfigRequest request) {
        ImportConfig config = importConfigRepository.findByCoachId(request.getCoachId())
                .orElseGet(ImportConfig::new);

        config.setCoachId(request.getCoachId());
        config.setEnabled(request.isEnabled());
        config.getAthletes().clear();
        request.getAthletes().forEach(a ->
                config.getAthletes().add(new ImportAthleteConfig(a.getAthleteId(), a.getWeightIndex())));
        config.getTrainingDays().clear();
        if (request.getTrainingDays() != null) {
            config.getTrainingDays().addAll(request.getTrainingDays());
        }
        // Reset lastImportedMonday so the next scheduler/dashboard trigger re-imports with the new athlete list
        config.setLastImportedMonday(null);

        return new ImportConfigResponse(importConfigRepository.save(config));
    }

    public void recordSuccess(Long configId, java.time.LocalDate monday) {
        ImportConfig config = importConfigRepository.findById(configId)
                .orElseThrow(() -> new RuntimeException("ImportConfig not found: " + configId));
        config.setLastAttemptAt(java.time.LocalDateTime.now());
        config.setLastSuccessAt(java.time.LocalDateTime.now());
        config.setLastImportedMonday(monday);
        config.setLastError(null);
        importConfigRepository.save(config);
    }

    public void recordFailure(Long configId, String error) {
        ImportConfig config = importConfigRepository.findById(configId)
                .orElseThrow(() -> new RuntimeException("ImportConfig not found: " + configId));
        config.setLastAttemptAt(java.time.LocalDateTime.now());
        config.setLastError(error);
        importConfigRepository.save(config);
    }
}