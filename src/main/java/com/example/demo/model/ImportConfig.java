package com.example.demo.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "import_config")
@Getter
@Setter
public class ImportConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private Long coachId;

    private boolean enabled;

    // The Monday date of the last successfully imported week.
    private LocalDate lastImportedMonday;

    private java.time.LocalDateTime lastAttemptAt;
    private java.time.LocalDateTime lastSuccessAt;

    @Column(columnDefinition = "TEXT")
    private String lastError;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "import_config_athletes", joinColumns = @JoinColumn(name = "config_id"))
    private List<ImportAthleteConfig> athletes = new ArrayList<>();

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "import_config_days", joinColumns = @JoinColumn(name = "config_id"))
    @Column(name = "day")
    @Enumerated(EnumType.STRING)
    private List<DayOfWeek> trainingDays = new ArrayList<>();
}
