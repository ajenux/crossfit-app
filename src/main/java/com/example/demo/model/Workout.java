package com.example.demo.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Table(name = "workouts")
@Getter
@Setter
public class Workout {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private WorkoutType type;

    @Column(nullable = false)
    private LocalDate scheduledDate;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "athlete_id", nullable = false)
    private Athlete athlete;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "coach_id", nullable = false)
    private Coach coach;

    @Column(nullable = false, columnDefinition = "boolean not null default false")
    private boolean completed = false;

    // Set only for sheet-imported workouts. Format: "{monday_date}-D{dayNum}" e.g. "2026-06-16-D1".
    // Null for manually created workouts. Used to detect existing imports (idempotency).
    @Column(name = "sheets_source_key")
    private String sheetsSourceKey;

    // Literal "Semana N" label as written by the coach in the sheet — lets the athlete
    // see the same week identifier the coach uses, instead of a recomputed calendar week
    // (which does not reliably match the sheet's own numbering). Null for manual workouts.
    @Column(name = "sheets_week_label")
    private String sheetsWeekLabel;
}