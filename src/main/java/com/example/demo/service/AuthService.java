package com.example.demo.service;

import com.example.demo.dto.AuthResponse;
import com.example.demo.dto.LoginRequest;
import com.example.demo.dto.RegisterRequest;
import com.example.demo.model.Athlete;
import com.example.demo.model.Coach;
import com.example.demo.model.Role;
import com.example.demo.model.User;
import com.example.demo.model.RefreshToken;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import com.example.demo.repository.UserRepository;
import com.example.demo.security.JwtService;
import lombok.RequiredArgsConstructor;
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
    private final AuthenticationManager authenticationManager;

    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already in use: " + request.getEmail());
        }

        User user = new User();
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setRole(request.getRole());
        userRepository.save(user);

        Long profileId = createProfile(user, request.getName());
        String token = jwtService.generateToken(user);
        RefreshToken refreshToken = refreshTokenService.createRefreshToken(user);
        return new AuthResponse(token, refreshToken.getToken(), user.getRole().name(), profileId);
    }

    public AuthResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("User not found"));
        Long profileId = resolveProfileId(user);
        String token = jwtService.generateToken(user);
        RefreshToken refreshToken = refreshTokenService.createRefreshToken(user);
        return new AuthResponse(token, refreshToken.getToken(), user.getRole().name(), profileId);
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
}