package com.example.demo.service;

import com.example.demo.dto.WorkoutRequest;
import com.example.demo.dto.WorkoutResponse;
import com.example.demo.model.Athlete;
import com.example.demo.model.Coach;
import com.example.demo.model.Workout;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import com.example.demo.repository.WorkoutRepository;
import com.example.demo.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
@RequiredArgsConstructor
public class WorkoutService {

    private final WorkoutRepository workoutRepository;
    private final AthleteRepository athleteRepository;
    private final CoachRepository coachRepository;

    public Page<WorkoutResponse> findAll(Pageable pageable) {
        if (SecurityUtils.isAthlete()) {
            Long athleteId = currentAthleteId();
            return workoutRepository.findByAthleteId(athleteId, pageable).map(WorkoutResponse::new);
        }
        return workoutRepository.findAll(pageable).map(WorkoutResponse::new);
    }

    public Page<WorkoutResponse> findByAthlete(Long athleteId, Pageable pageable) {
        if (SecurityUtils.isAthlete()) {
            assertIsCurrentAthlete(athleteId);
        }
        return workoutRepository.findByAthleteId(athleteId, pageable).map(WorkoutResponse::new);
    }

    public Page<WorkoutResponse> findByCoach(Long coachId, Pageable pageable) {
        return workoutRepository.findByCoachId(coachId, pageable).map(WorkoutResponse::new);
    }

    public WorkoutResponse findById(Long id) {
        Workout workout = workoutRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Workout not found with id: " + id));
        if (SecurityUtils.isAthlete()) {
            assertIsCurrentAthlete(workout.getAthlete().getId());
        }
        return new WorkoutResponse(workout);
    }

    public WorkoutResponse create(WorkoutRequest request) {
        Athlete athlete = athleteRepository.findById(request.getAthleteId())
                .orElseThrow(() -> new RuntimeException("Athlete not found with id: " + request.getAthleteId()));
        Coach coach = coachRepository.findById(request.getCoachId())
                .orElseThrow(() -> new RuntimeException("Coach not found with id: " + request.getCoachId()));

        Workout workout = new Workout();
        workout.setName(request.getName());
        workout.setDescription(request.getDescription());
        workout.setType(request.getType());
        workout.setScheduledDate(request.getScheduledDate());
        workout.setAthlete(athlete);
        workout.setCoach(coach);
        return new WorkoutResponse(workoutRepository.save(workout));
    }

    public WorkoutResponse update(Long id, WorkoutRequest request) {
        Workout workout = workoutRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Workout not found with id: " + id));
        Athlete athlete = athleteRepository.findById(request.getAthleteId())
                .orElseThrow(() -> new RuntimeException("Athlete not found with id: " + request.getAthleteId()));
        Coach coach = coachRepository.findById(request.getCoachId())
                .orElseThrow(() -> new RuntimeException("Coach not found with id: " + request.getCoachId()));

        workout.setName(request.getName());
        workout.setDescription(request.getDescription());
        workout.setType(request.getType());
        workout.setScheduledDate(request.getScheduledDate());
        workout.setAthlete(athlete);
        workout.setCoach(coach);
        return new WorkoutResponse(workoutRepository.save(workout));
    }

    public void delete(Long id) {
        if (!workoutRepository.existsById(id)) {
            throw new RuntimeException("Workout not found with id: " + id);
        }
        workoutRepository.deleteById(id);
    }

    private Long currentAthleteId() {
        String email = SecurityUtils.getCurrentUserEmail();
        return athleteRepository.findByEmail(email)
                .map(Athlete::getId)
                .orElseThrow(() -> new RuntimeException("Athlete profile not found for user: " + email));
    }

    private void assertIsCurrentAthlete(Long athleteId) {
        if (!athleteId.equals(currentAthleteId())) {
            throw new AccessDeniedException("Access denied: you can only access your own data");
        }
    }
}
