package com.example.demo.service;

import com.example.demo.dto.CoachAvailabilityRequest;
import com.example.demo.dto.CoachAvailabilityResponse;
import com.example.demo.model.Coach;
import com.example.demo.model.CoachAvailability;
import com.example.demo.repository.CoachAvailabilityRepository;
import com.example.demo.repository.CoachRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CoachAvailabilityService {

    private final CoachAvailabilityRepository availabilityRepository;
    private final CoachRepository coachRepository;

    public CoachAvailabilityResponse create(CoachAvailabilityRequest request) {
        Coach coach = coachRepository.findById(request.getCoachId())
                .orElseThrow(() -> new RuntimeException("Coach not found"));

        CoachAvailability availability = new CoachAvailability();
        availability.setCoach(coach);
        availability.setRecurring(request.isRecurring());
        availability.setDayOfWeek(request.getDayOfWeek());
        availability.setSpecificDate(request.getSpecificDate());
        availability.setStartTime(request.getStartTime());
        availability.setEndTime(request.getEndTime());

        return toResponse(availabilityRepository.save(availability));
    }

    public List<CoachAvailabilityResponse> findByCoach(Long coachId) {
        return availabilityRepository.findByCoachId(coachId)
                .stream().map(this::toResponse).toList();
    }

    public void delete(Long id) {
        availabilityRepository.deleteById(id);
    }

    private CoachAvailabilityResponse toResponse(CoachAvailability a) {
        return new CoachAvailabilityResponse(
                a.getId(),
                a.getCoach().getId(),
                a.getCoach().getName(),
                a.isRecurring(),
                a.getDayOfWeek(),
                a.getSpecificDate(),
                a.getStartTime(),
                a.getEndTime()
        );
    }
}
