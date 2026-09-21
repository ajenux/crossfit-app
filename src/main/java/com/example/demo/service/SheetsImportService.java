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
import java.time.DayOfWeek;
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

    public List<String> getSheetNames() throws IOException, GeneralSecurityException {
        return googleSheetsService.getSheetNames();
    }

    public List<GoogleSheetsService.ParsedWeek> listWeeks(String sheetName) throws IOException, GeneralSecurityException {
        return googleSheetsService.parseWeeks(sheetName);
    }

    public SheetsImportResponse importWeek(SheetsImportRequest request) throws IOException, GeneralSecurityException {
        List<GoogleSheetsService.ParsedWeek> weeks = googleSheetsService.parseWeeks(request.getSheetName());

        GoogleSheetsService.ParsedWeek week = weeks.stream()
                .filter(w -> w.weekNumber() == request.getWeekNumber())
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Week " + request.getWeekNumber() + " not found"));

        Coach coach = coachRepository.findById(request.getCoachId())
                .orElseThrow(() -> new RuntimeException("Coach not found: " + request.getCoachId()));

        List<String> importedNames = new ArrayList<>();

        List<DayOfWeek> trainingDays = request.getTrainingDays();

        for (Map.Entry<Integer, String> entry : week.dayContent().entrySet()) {
            int dayNum = entry.getKey();
            String raw = entry.getValue();
            LocalDate date = resolveDate(request.getStartDate(), dayNum, trainingDays);
            WorkoutType type = detectType(raw);
            // Key uniquely identifies this workout's sheet origin — enables safe re-import without duplicates
            String sourceKey = request.getStartDate().toString() + "-D" + dayNum;
            // Matches the sheet's own "Dia N" header — no week number or athlete name
            // (the athlete already knows who they are; the week number was a source of
            // confusion since it didn't always match the sheet's own "Semana N" label).
            String name = "Dia " + dayNum;

            for (SheetsImportRequest.AthleteImport athleteImport : request.getAthletes()) {
                Athlete athlete = athleteRepository.findById(athleteImport.getAthleteId())
                        .orElseThrow(() -> new RuntimeException("Athlete not found: " + athleteImport.getAthleteId()));
                String description = applyWeights(raw, athleteImport.getWeightIndex());

                workoutRepository.findByAthleteIdAndSheetsSourceKey(athlete.getId(), sourceKey)
                        .ifPresentOrElse(existing -> {
                            // Update content in case coach corrected the sheet; preserve completed state
                            existing.setName(name);
                            existing.setDescription(description);
                            existing.setScheduledDate(date);
                            existing.setType(type);
                            existing.setSheetsWeekLabel(week.label());
                            workoutRepository.save(existing);
                            importedNames.add(existing.getName() + " (updated)");
                        }, () -> {
                            Workout w = buildWorkout(name, description, type, date, athlete, coach);
                            w.setSheetsSourceKey(sourceKey);
                            w.setSheetsWeekLabel(week.label());
                            workoutRepository.save(w);
                            importedNames.add(w.getName());
                        });
            }
        }

        return new SheetsImportResponse(request.getWeekNumber(), importedNames.size(), importedNames);
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

    private String applyWeights(String content, int weightIndex) {
        return WEIGHT_PATTERN.matcher(content)
                .replaceAll(m -> "(" + (weightIndex == 0 ? m.group(1) : m.group(2)) + ")");
    }

    // startDate is expected to be the Monday of the target week.
    // trainingDays maps Dia N (1-based) to a specific weekday offset from Monday.
    private LocalDate resolveDate(LocalDate startDate, int dayNum, List<DayOfWeek> trainingDays) {
        if (trainingDays != null && !trainingDays.isEmpty() && dayNum <= trainingDays.size()) {
            DayOfWeek target = trainingDays.get(dayNum - 1);
            int offset = target.getValue() - DayOfWeek.MONDAY.getValue();
            return startDate.plusDays(offset);
        }
        return startDate.plusDays(dayNum - 1);
    }

    private WorkoutType detectType(String content) {
        String lower = content.toLowerCase();
        if (lower.contains("amrap")) return WorkoutType.AMRAP;
        if (lower.contains("emom")) return WorkoutType.EMOM;
        return WorkoutType.FOR_TIME;
    }
}