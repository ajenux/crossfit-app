package com.example.demo.service;

import dev.langchain4j.model.ollama.OllamaChatModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AiService {

    private final OllamaChatModel model;

    public AiService() {
        this.model = OllamaChatModel.builder()
                .baseUrl("http://localhost:11434")
                .modelName("llama3.2")
                .build();
    }

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

        ChatResponse response = model.chat(request);
        return response.aiMessage().text();
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

        ChatResponse response = model.chat(request);
        return response.aiMessage().text();
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

        ChatResponse response = model.chat(request);
        return response.aiMessage().text();
    }
}
