package com.example.demo.config;

import com.example.demo.model.*;
import com.example.demo.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Seeds the database with demo data on startup.
 * Only runs when the "demo" Spring profile is active.
 * Safe to run multiple times — skips seeding if data already exists.
 *
 * Demo accounts:
 *   coach@demo.com   / Demo1234  (COACH)
 *   athlete1@demo.com / Demo1234 (ATHLETE — assigned to demo coach)
 *   athlete2@demo.com / Demo1234 (ATHLETE — assigned to demo coach)
 */
@Slf4j
@Component
@Profile("demo")
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final AthleteRepository athleteRepository;
    private final CoachRepository coachRepository;
    private final WorkoutRepository workoutRepository;
    private final CoachAvailabilityRepository availabilityRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(String... args) {
        if (userRepository.count() > 0) {
            log.info("Demo data already present — skipping seed.");
            return;
        }

        log.info("Seeding demo data...");

        String password = passwordEncoder.encode("Demo1234");

        // Coach
        User coachUser = new User();
        coachUser.setEmail("coach@demo.com");
        coachUser.setPassword(password);
        coachUser.setRole(Role.COACH);
        userRepository.save(coachUser);

        Coach coach = new Coach();
        coach.setName("Alex Rivera");
        coach.setEmail("coach@demo.com");
        coach.setUser(coachUser);
        coachRepository.save(coach);

        // Athlete 1
        User user1 = new User();
        user1.setEmail("athlete1@demo.com");
        user1.setPassword(password);
        user1.setRole(Role.ATHLETE);
        userRepository.save(user1);

        Athlete athlete1 = new Athlete();
        athlete1.setName("Sofia Martinez");
        athlete1.setEmail("athlete1@demo.com");
        athlete1.setUser(user1);
        athlete1.setCoach(coach);
        athleteRepository.save(athlete1);

        // Athlete 2
        User user2 = new User();
        user2.setEmail("athlete2@demo.com");
        user2.setPassword(password);
        user2.setRole(Role.ATHLETE);
        userRepository.save(user2);

        Athlete athlete2 = new Athlete();
        athlete2.setName("Luis Gomez");
        athlete2.setEmail("athlete2@demo.com");
        athlete2.setUser(user2);
        athlete2.setCoach(coach);
        athleteRepository.save(athlete2);

        // Workouts for Sofia
        createWorkout("Monday Grind", "Full body conditioning — push hard.", WorkoutType.AMRAP, LocalDate.now().plusDays(1), athlete1, coach);
        createWorkout("Heavy Pulls", "Deadlift focus — 5 sets of 5 reps at 80%.", WorkoutType.STRENGTH, LocalDate.now().plusDays(3), athlete1, coach);
        createWorkout("Cardio Blast", "Row 500m, 21 burpees, 400m run. For time.", WorkoutType.FOR_TIME, LocalDate.now().plusDays(5), athlete1, coach);

        // Workouts for Luis
        createWorkout("EMOM Power", "Every minute: 5 power cleans + 10 air squats.", WorkoutType.EMOM, LocalDate.now().plusDays(2), athlete2, coach);
        createWorkout("Endurance Day", "5km run at conversational pace.", WorkoutType.ENDURANCE, LocalDate.now().plusDays(4), athlete2, coach);

        // Coach availability
        createRecurringSlot(coach, DayOfWeek.MONDAY, LocalTime.of(7, 0), LocalTime.of(12, 0));
        createRecurringSlot(coach, DayOfWeek.WEDNESDAY, LocalTime.of(7, 0), LocalTime.of(12, 0));
        createRecurringSlot(coach, DayOfWeek.FRIDAY, LocalTime.of(7, 0), LocalTime.of(11, 0));

        log.info("Demo seed complete. Accounts: coach@demo.com, athlete1@demo.com, athlete2@demo.com (password: Demo1234)");
    }

    private void createWorkout(String name, String description, WorkoutType type,
                               LocalDate date, Athlete athlete, Coach coach) {
        Workout w = new Workout();
        w.setName(name);
        w.setDescription(description);
        w.setType(type);
        w.setScheduledDate(date);
        w.setAthlete(athlete);
        w.setCoach(coach);
        workoutRepository.save(w);
    }

    private void createRecurringSlot(Coach coach, DayOfWeek day, LocalTime start, LocalTime end) {
        CoachAvailability slot = new CoachAvailability();
        slot.setCoach(coach);
        slot.setRecurring(true);
        slot.setDayOfWeek(day);
        slot.setStartTime(start);
        slot.setEndTime(end);
        availabilityRepository.save(slot);
    }
}
