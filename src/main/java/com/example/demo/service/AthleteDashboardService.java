package com.example.demo.service;

import com.example.demo.dto.AthleteDashboardResponse;
import com.example.demo.dto.CoachAvailabilityResponse;
import com.example.demo.dto.WorkoutResponse;
import com.example.demo.model.Athlete;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachAvailabilityRepository;
import com.example.demo.repository.WorkoutRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AthleteDashboardService {

    private final AthleteRepository athleteRepository;
    private final WorkoutRepository workoutRepository;
    private final CoachAvailabilityRepository availabilityRepository;

    public AthleteDashboardResponse getDashboard(Long athleteId) {
        Athlete athlete = athleteRepository.findById(athleteId)
                .orElseThrow(() -> new RuntimeException("Athlete not found"));

        List<WorkoutResponse> workouts = workoutRepository.findByAthleteId(athleteId)
                .stream().map(WorkoutResponse::new).toList();

        List<CoachAvailabilityResponse> availability = List.of();
        if (athlete.getCoach() != null) {
            availability = availabilityRepository.findByCoachId(athlete.getCoach().getId())
                    .stream().map(a -> new CoachAvailabilityResponse(
                            a.getId(),
                            a.getCoach().getId(),
                            a.getCoach().getName(),
                            a.isRecurring(),
                            a.getDayOfWeek(),
                            a.getSpecificDate(),
                            a.getStartTime(),
                            a.getEndTime()
                    )).toList();
        }

        return new AthleteDashboardResponse(
                athlete.getId(),
                athlete.getName(),
                athlete.getCoach() != null ? athlete.getCoach().getName() : null,
                workouts,
                availability
        );
    }
}
