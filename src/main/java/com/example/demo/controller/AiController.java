package com.example.demo.controller;

import com.example.demo.service.AiService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
public class AiController {

    private final AiService aiService;

    @PostMapping("/explain")
    public Map<String, String> explain(@RequestBody Map<String, String> body) {
        String question = body.get("question");
        String answer = aiService.explain(question);
        return Map.of("answer", answer);
    }

    @PostMapping("/generate-workout")
    public Map<String, String> generateWorkout(@RequestBody Map<String, String> body) {
        String name = body.get("name");
        String type = body.get("type");
        String description = aiService.generateWorkoutDescription(name, type);
        return Map.of("description", description);
    }
}
