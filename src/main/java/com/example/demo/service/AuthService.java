package com.example.demo.service;

import com.example.demo.dto.AuthResponse;
import com.example.demo.dto.LoginRequest;
import com.example.demo.dto.RegisterRequest;
import com.example.demo.model.Athlete;
import com.example.demo.model.Coach;
import com.example.demo.model.EmailVerificationToken;
import com.example.demo.model.PasswordResetToken;
import com.example.demo.model.Role;
import com.example.demo.model.User;
import com.example.demo.model.RefreshToken;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import com.example.demo.repository.UserRepository;
import com.example.demo.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final AthleteRepository athleteRepository;
    private final CoachRepository coachRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final PasswordResetService passwordResetService;
    private final EmailVerificationService emailVerificationService;
    private final EmailService emailService;
    private final AuthenticationManager authenticationManager;

    @Value("${app.frontend-url}")
    private String frontendUrl;

    public void register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already in use: " + request.getEmail());
        }

        User user = new User();
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setRole(request.getRole());
        user.setEmailVerified(false);
        userRepository.save(user);

        createProfile(user, request.getName());

        EmailVerificationToken verificationToken = emailVerificationService.createToken(user);
        String verifyLink = frontendUrl + "/#/verify-email?token=" + verificationToken.getToken();
        emailService.sendVerificationEmail(user.getEmail(), verifyLink);
    }

    public AuthResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("User not found"));
        if (!user.isEmailVerified()) {
            throw new EmailNotVerifiedException("Please verify your email before logging in");
        }
        Long profileId = resolveProfileId(user);
        String token = jwtService.generateToken(user);
        RefreshToken refreshToken = refreshTokenService.createRefreshToken(user);
        return new AuthResponse(token, refreshToken.getToken(), user.getRole().name(), profileId);
    }

    public void resendVerification(String email) {
        // Always behave the same whether or not the email exists / is already
        // verified, to avoid leaking which addresses are registered.
        userRepository.findByEmail(email)
                .filter(user -> !user.isEmailVerified())
                .ifPresent(user -> {
                    EmailVerificationToken verificationToken = emailVerificationService.createToken(user);
                    String verifyLink = frontendUrl + "/#/verify-email?token=" + verificationToken.getToken();
                    emailService.sendVerificationEmail(user.getEmail(), verifyLink);
                });
    }

    public void verifyEmail(String token) {
        User user = emailVerificationService.verifyAndConsume(token);
        user.setEmailVerified(true);
        userRepository.save(user);
    }

    public void forgotPassword(String email) {
        // Always behave the same whether or not the email exists, to avoid leaking
        // which addresses are registered.
        userRepository.findByEmail(email).ifPresent(user -> {
            PasswordResetToken resetToken = passwordResetService.createToken(user);
            String resetLink = frontendUrl + "/#/reset-password?token=" + resetToken.getToken();
            emailService.sendPasswordResetEmail(user.getEmail(), resetLink);
        });
    }

    public void resetPassword(String token, String newPassword) {
        User user = passwordResetService.verifyAndConsume(token);
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        refreshTokenService.deleteByUser(user);
    }

    private Long createProfile(User user, String name) {
        String displayName = (name != null && !name.isBlank()) ? name : user.getEmail();
        if (user.getRole() == Role.ATHLETE) {
            Athlete athlete = new Athlete();
            athlete.setName(displayName);
            athlete.setEmail(user.getEmail());
            athlete.setUser(user);
            return athleteRepository.save(athlete).getId();
        } else if (user.getRole() == Role.COACH) {
            Coach coach = new Coach();
            coach.setName(displayName);
            coach.setEmail(user.getEmail());
            coach.setUser(user);
            return coachRepository.save(coach).getId();
        }
        return null;
    }

    public Long resolveProfileId(User user) {
        if (user.getRole() == Role.ATHLETE) {
            return athleteRepository.findByUser(user)
                    .map(Athlete::getId)
                    .orElse(null);
        } else if (user.getRole() == Role.COACH) {
            return coachRepository.findByUser(user)
                    .map(Coach::getId)
                    .orElse(null);
        }
        return null;
    }

    public static class EmailNotVerifiedException extends RuntimeException {
        public EmailNotVerifiedException(String message) {
            super(message);
        }
    }
}