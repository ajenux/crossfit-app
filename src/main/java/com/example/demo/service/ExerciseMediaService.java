package com.example.demo.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

@Service
public class ExerciseMediaService {

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
                Object gifUrl = results.get(0).get("gifUrl");
                return gifUrl != null ? gifUrl.toString() : null;
            }
        } catch (Exception e) {
            // Media is optional — return null if API fails
        }
        return null;
    }
}
