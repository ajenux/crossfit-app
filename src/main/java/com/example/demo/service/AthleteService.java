package com.example.demo.service;

import com.example.demo.dto.AthleteRequest;
import com.example.demo.dto.AthleteResponse;
import com.example.demo.model.Athlete;
import com.example.demo.model.Coach;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
@RequiredArgsConstructor
public class AthleteService {

    private final AthleteRepository athleteRepository;
    private final CoachRepository coachRepository;

    public List<AthleteResponse> findAll() {
        return athleteRepository.findAll().stream()
                .map(AthleteResponse::new)
                .toList();
    }

    public List<AthleteResponse> findByCoach(Long coachId) {
        return athleteRepository.findByCoachId(coachId).stream()
                .map(AthleteResponse::new)
                .toList();
    }

    public AthleteResponse findById(Long id) {
        Athlete athlete = athleteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Athlete not found with id: " + id));
        return new AthleteResponse(athlete);
    }

    public AthleteResponse create(AthleteRequest request) {
        if (athleteRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already in use: " + request.getEmail());
        }
        Coach coach = coachRepository.findById(request.getCoachId())
                .orElseThrow(() -> new RuntimeException("Coach not found with id: " + request.getCoachId()));

        Athlete athlete = new Athlete();
        athlete.setName(request.getName());
        athlete.setEmail(request.getEmail());
        athlete.setCoach(coach);
        return new AthleteResponse(athleteRepository.save(athlete));
    }

    public AthleteResponse update(Long id, AthleteRequest request) {
        Athlete athlete = athleteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Athlete not found with id: " + id));
        Coach coach = coachRepository.findById(request.getCoachId())
                .orElseThrow(() -> new RuntimeException("Coach not found with id: " + request.getCoachId()));

        athlete.setName(request.getName());
        athlete.setEmail(request.getEmail());
        athlete.setCoach(coach);
        return new AthleteResponse(athleteRepository.save(athlete));
    }

    public void delete(Long id) {
        if (!athleteRepository.existsById(id)) {
            throw new RuntimeException("Athlete not found with id: " + id);
        }
        athleteRepository.deleteById(id);
    }
}