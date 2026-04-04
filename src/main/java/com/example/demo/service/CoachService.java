package com.example.demo.service;

import com.example.demo.dto.CoachRequest;
import com.example.demo.dto.CoachResponse;
import com.example.demo.model.Coach;
import com.example.demo.repository.CoachRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
@RequiredArgsConstructor
public class CoachService {

    private final CoachRepository coachRepository;

    public List<CoachResponse> findAll() {
        return coachRepository.findAll().stream()
                .map(CoachResponse::new)
                .toList();
    }

    public CoachResponse findById(Long id) {
        Coach coach = coachRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Coach not found with id: " + id));
        return new CoachResponse(coach);
    }

    public CoachResponse create(CoachRequest request) {
        if (coachRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already in use: " + request.getEmail());
        }
        Coach coach = new Coach();
        coach.setName(request.getName());
        coach.setEmail(request.getEmail());
        return new CoachResponse(coachRepository.save(coach));
    }

    public CoachResponse update(Long id, CoachRequest request) {
        Coach coach = coachRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Coach not found with id: " + id));
        coach.setName(request.getName());
        coach.setEmail(request.getEmail());
        return new CoachResponse(coachRepository.save(coach));
    }

    public void delete(Long id) {
        if (!coachRepository.existsById(id)) {
            throw new RuntimeException("Coach not found with id: " + id);
        }
        coachRepository.deleteById(id);
    }
}