package com.example.demo.service;

import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AiService {

    private final ChatLanguageModel model;

    public String generateWorkoutDescription(String name, String type) {
        ChatRequest request = ChatRequest.builder()
                .messages(List.of(
                        SystemMessage.from("""
                                You are a CrossFit coach assistant. Generate a concise workout description
                                including exercises, sets/reps or time structure, and a brief coaching tip.
                                Keep it under 100 words. Be practical and motivating.
                                """),
                        UserMessage.from("Generate a description for a CrossFit workout named '" + name + "' of type " + type + ".")
                ))
                .build();
        return chat(request);
    }

    public String explainExercise(String exerciseName) {
        ChatRequest request = ChatRequest.builder()
                .messages(List.of(
                        SystemMessage.from("""
                                You are a CrossFit coach assistant. Explain the given exercise clearly:
                                - What muscles it targets
                                - How to perform it step by step
                                - Common mistakes to avoid
                                Keep it under 120 words.
                                """),
                        UserMessage.from("Explain the exercise: " + exerciseName)
                ))
                .build();
        return chat(request);
    }

    public String explain(String question) {
        ChatRequest request = ChatRequest.builder()
                .messages(List.of(
                        SystemMessage.from("""
                                You are a CrossFit coach assistant. Your job is to explain CrossFit exercises,
                                workout types, and terminology in a clear and simple way.
                                Keep answers concise and practical. Use examples when helpful.
                                If the question is not related to CrossFit or fitness, politely redirect.
                                """),
                        UserMessage.from(question)
                ))
                .build();
        return chat(request);
    }

    private String chat(ChatRequest request) {
        try {
            ChatResponse response = model.chat(request);
            return response.aiMessage().text();
        } catch (Exception e) {
            throw new AiUnavailableException("AI service is currently unavailable", e);
        }
    }

    public static class AiUnavailableException extends RuntimeException {
        public AiUnavailableException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}