package com.example.demo.service;

import com.example.demo.dto.SheetsImportRequest;
import com.example.demo.dto.SheetsImportResponse;
import com.example.demo.model.Athlete;
import com.example.demo.model.Coach;
import com.example.demo.model.Workout;
import com.example.demo.model.WorkoutType;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import com.example.demo.repository.WorkoutRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

@Service
@Transactional
@RequiredArgsConstructor
public class SheetsImportService {

    private final GoogleSheetsService googleSheetsService;
    private final WorkoutRepository workoutRepository;
    private final AthleteRepository athleteRepository;
    private final CoachRepository coachRepository;

    // Matches weight patterns like (9/3), (16/9), (7,5/5)
    private static final Pattern WEIGHT_PATTERN =
            Pattern.compile("\\(([\\d,\\.]+)/([\\d,\\.]+)\\)");

    public List<GoogleSheetsService.ParsedWeek> listWeeks() throws IOException, GeneralSecurityException {
        return googleSheetsService.parseWeeks();
    }

    public SheetsImportResponse importWeek(SheetsImportRequest request) throws IOException, GeneralSecurityException {
        List<GoogleSheetsService.ParsedWeek> weeks = googleSheetsService.parseWeeks();

        GoogleSheetsService.ParsedWeek week = weeks.stream()
                .filter(w -> w.weekNumber() == request.getWeekNumber())
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Week " + request.getWeekNumber() + " not found"));

        Athlete athleteA = athleteRepository.findById(request.getAthleteAId())
                .orElseThrow(() -> new RuntimeException("Athlete not found: " + request.getAthleteAId()));
        Athlete athleteB = athleteRepository.findById(request.getAthleteBId())
                .orElseThrow(() -> new RuntimeException("Athlete not found: " + request.getAthleteBId()));
        Coach coach = coachRepository.findById(request.getCoachId())
                .orElseThrow(() -> new RuntimeException("Coach not found: " + request.getCoachId()));

        List<String> createdNames = new ArrayList<>();

        for (Map.Entry<Integer, String> entry : week.dayContent().entrySet()) {
            int dayNum = entry.getKey();
            String raw = entry.getValue();
            LocalDate date = request.getStartDate().plusDays(dayNum - 1);
            WorkoutType type = detectType(raw);

            Workout wA = buildWorkout(
                    "S" + request.getWeekNumber() + "-D" + dayNum + " " + athleteA.getName(),
                    applyWeights(raw, true), type, date, athleteA, coach);
            workoutRepository.save(wA);
            createdNames.add(wA.getName());

            Workout wB = buildWorkout(
                    "S" + request.getWeekNumber() + "-D" + dayNum + " " + athleteB.getName(),
                    applyWeights(raw, false), type, date, athleteB, coach);
            workoutRepository.save(wB);
            createdNames.add(wB.getName());
        }

        return new SheetsImportResponse(request.getWeekNumber(), createdNames.size(), createdNames);
    }

    private Workout buildWorkout(String name, String description, WorkoutType type,
                                  LocalDate date, Athlete athlete, Coach coach) {
        Workout w = new Workout();
        w.setName(name);
        w.setDescription(description);
        w.setType(type);
        w.setScheduledDate(date);
        w.setAthlete(athlete);
        w.setCoach(coach);
        return w;
    }

    // For athlete A (male/heavier): keep first weight in (X/Y) → (X)
    // For athlete B (female/lighter): keep second weight → (Y)
    private String applyWeights(String content, boolean useMale) {
        return WEIGHT_PATTERN.matcher(content)
                .replaceAll(m -> "(" + (useMale ? m.group(1) : m.group(2)) + ")");
    }

    private WorkoutType detectType(String content) {
        String lower = content.toLowerCase();
        if (lower.contains("amrap")) return WorkoutType.AMRAP;
        if (lower.contains("emom")) return WorkoutType.EMOM;
        return WorkoutType.FOR_TIME;
    }
}