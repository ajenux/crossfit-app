package com.example.demo.config;

import dev.langchain4j.model.anthropic.AnthropicChatModel;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.ollama.OllamaChatModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AiConfig {

    @Value("${anthropic.api.key:}")
    private String anthropicApiKey;

    @Value("${ollama.base-url:http://localhost:11434}")
    private String ollamaBaseUrl;

    @Bean
    public ChatLanguageModel chatLanguageModel() {
        if (anthropicApiKey != null && !anthropicApiKey.isBlank()) {
            return AnthropicChatModel.builder()
                    .apiKey(anthropicApiKey)
                    .modelName("claude-haiku-4-5-20251001")
                    .maxTokens(256)
                    .build();
        }
        return OllamaChatModel.builder()
                .baseUrl(ollamaBaseUrl)
                .modelName("llama3.2")
                .build();
    }
}
