package com.example.demo.service;

import com.example.demo.dto.WorkoutRequest;
import com.example.demo.dto.WorkoutResponse;
import com.example.demo.model.Athlete;
import com.example.demo.model.Coach;
import com.example.demo.model.Workout;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import com.example.demo.repository.WorkoutRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
@RequiredArgsConstructor
public class WorkoutService {

    private final WorkoutRepository workoutRepository;
    private final AthleteRepository athleteRepository;
    private final CoachRepository coachRepository;

    public List<WorkoutResponse> findAll() {
        return workoutRepository.findAll().stream()
                .map(WorkoutResponse::new)
                .toList();
    }

    public List<WorkoutResponse> findByAthlete(Long athleteId) {
        return workoutRepository.findByAthleteId(athleteId).stream()
                .map(WorkoutResponse::new)
                .toList();
    }

    public List<WorkoutResponse> findByCoach(Long coachId) {
        return workoutRepository.findByCoachId(coachId).stream()
                .map(WorkoutResponse::new)
                .toList();
    }

    public WorkoutResponse findById(Long id) {
        Workout workout = workoutRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Workout not found with id: " + id));
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
}