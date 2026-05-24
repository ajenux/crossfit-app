package com.example.demo.controller;

import com.example.demo.service.AiService;
import com.example.demo.service.ExerciseMediaService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
public class AiController {

    private final AiService aiService;
    private final ExerciseMediaService exerciseMediaService;

    @PostMapping("/explain")
    public Map<String, String> explain(@RequestBody Map<String, String> body) {
        String question = body.get("question");
        String answer = aiService.explain(question);
        return Map.of("answer", answer);
    }

    @PostMapping("/exercise")
    public Map<String, String> explainExercise(@RequestBody Map<String, String> body) {
        String exercise = body.get("exercise");
        String explanation = aiService.explainExercise(exercise);
        String gifUrl = exerciseMediaService.getGifUrl(exercise);

        Map<String, String> response = new HashMap<>();
        response.put("explanation", explanation);
        if (gifUrl != null) response.put("gifUrl", gifUrl);
        return response;
    }

    @PostMapping("/generate-workout")
    public Map<String, String> generateWorkout(@RequestBody Map<String, String> body) {
        String name = body.get("name");
        String type = body.get("type");
        String description = aiService.generateWorkoutDescription(name, type);
        return Map.of("description", description);
    }
}
