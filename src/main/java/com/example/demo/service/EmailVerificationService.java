package com.example.demo.service;

import com.example.demo.model.EmailVerificationToken;
import com.example.demo.model.User;
import com.example.demo.repository.EmailVerificationTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
@Transactional
@RequiredArgsConstructor
public class EmailVerificationService {

    private final EmailVerificationTokenRepository emailVerificationTokenRepository;

    @Value("${app.email-verification.expiration-hours:24}")
    private long expirationHours;

    public EmailVerificationToken createToken(User user) {
        emailVerificationTokenRepository.deleteByUser(user);

        EmailVerificationToken token = new EmailVerificationToken();
        token.setUser(user);
        token.setToken(UUID.randomUUID().toString());
        token.setExpiryDate(Instant.now().plusSeconds(expirationHours * 3600));
        return emailVerificationTokenRepository.save(token);
    }

    public User verifyAndConsume(String rawToken) {
        EmailVerificationToken token = emailVerificationTokenRepository.findByToken(rawToken)
                .orElseThrow(() -> new InvalidTokenException("Invalid or already used verification link"));
        if (token.getExpiryDate().isBefore(Instant.now())) {
            emailVerificationTokenRepository.delete(token);
            throw new InvalidTokenException("This verification link has expired — request a new one");
        }
        User user = token.getUser();
        emailVerificationTokenRepository.delete(token);
        return user;
    }

    public static class InvalidTokenException extends RuntimeException {
        public InvalidTokenException(String message) {
            super(message);
        }
    }
}
