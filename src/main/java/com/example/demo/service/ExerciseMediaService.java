package com.example.demo.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

@Service
public class ExerciseMediaService {

    private static final Logger log = LoggerFactory.getLogger(ExerciseMediaService.class);

    private final RestClient restClient;
    private final String apiKey;

    public ExerciseMediaService(@Value("${exercisedb.api.key}") String apiKey) {
        this.apiKey = apiKey;
        this.restClient = RestClient.builder()
                .baseUrl("https://exercisedb.p.rapidapi.com")
                .build();
    }

    public String getGifUrl(String exerciseName) {
        try {
            List<Map<String, Object>> results = restClient.get()
                    .uri("/exercises/name/{name}?limit=1", exerciseName.toLowerCase())
                    .header("X-RapidAPI-Key", apiKey)
                    .header("X-RapidAPI-Host", "exercisedb.p.rapidapi.com")
                    .retrieve()
                    .body(List.class);

            if (results != null && !results.isEmpty()) {
                Object id = results.get(0).get("id");
                if (id != null) {
                    return "https://v2.exercisedb.io/image/" + id;
                }
            }
        } catch (Exception e) {
            log.error("ExerciseDB API error for '{}': {}", exerciseName, e.getMessage());
        }
        return null;
    }
}
