package com.example.demo.service;

import com.example.demo.dto.RegisterRequest;
import com.example.demo.model.Athlete;
import com.example.demo.model.Coach;
import com.example.demo.model.RefreshToken;
import com.example.demo.model.Role;
import com.example.demo.model.User;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import com.example.demo.repository.UserRepository;
import com.example.demo.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock UserRepository userRepository;
    @Mock AthleteRepository athleteRepository;
    @Mock CoachRepository coachRepository;
    @Mock PasswordEncoder passwordEncoder;
    @Mock JwtService jwtService;
    @Mock AuthenticationManager authenticationManager;
    @Mock RefreshTokenService refreshTokenService;

    @InjectMocks AuthService authService;

    private RegisterRequest athleteRequest;
    private RegisterRequest coachRequest;

    @BeforeEach
    void setUp() {
        athleteRequest = new RegisterRequest();
        athleteRequest.setName("Maria");
        athleteRequest.setEmail("maria@crossfit.com");
        athleteRequest.setPassword("pass123");
        athleteRequest.setRole(Role.ATHLETE);

        coachRequest = new RegisterRequest();
        coachRequest.setName("Juan");
        coachRequest.setEmail("juan@crossfit.com");
        coachRequest.setPassword("pass123");
        coachRequest.setRole(Role.COACH);
    }

    @Test
    void register_athlete_createsUserAndAthleteProfile() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(passwordEncoder.encode(anyString())).thenReturn("encoded");
        when(userRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        Athlete savedAthlete = new Athlete();
        savedAthlete.setId(5L);
        when(athleteRepository.save(any())).thenReturn(savedAthlete);
        when(jwtService.generateToken(any())).thenReturn("token123");
        RefreshToken rt = new RefreshToken();
        rt.setToken("refresh123");
        when(refreshTokenService.createRefreshToken(any())).thenReturn(rt);

        var response = authService.register(athleteRequest);

        assertThat(response.getToken()).isEqualTo("token123");
        assertThat(response.getRole()).isEqualTo("ATHLETE");
        assertThat(response.getProfileId()).isEqualTo(5L);
    }

    @Test
    void register_coach_createsUserAndCoachProfile() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(passwordEncoder.encode(anyString())).thenReturn("encoded");
        when(userRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        Coach savedCoach = new Coach();
        savedCoach.setId(3L);
        when(coachRepository.save(any())).thenReturn(savedCoach);
        when(jwtService.generateToken(any())).thenReturn("token456");
        RefreshToken rt = new RefreshToken();
        rt.setToken("refresh456");
        when(refreshTokenService.createRefreshToken(any())).thenReturn(rt);

        var response = authService.register(coachRequest);

        assertThat(response.getToken()).isEqualTo("token456");
        assertThat(response.getRole()).isEqualTo("COACH");
        assertThat(response.getProfileId()).isEqualTo(3L);
    }

    @Test
    void register_duplicateEmail_throwsException() {
        when(userRepository.existsByEmail(anyString())).thenReturn(true);

        assertThatThrownBy(() -> authService.register(athleteRequest))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("Email already in use");
    }

    @Test
    void login_returnsCorrectRoleAndProfileId() {
        User user = new User();
        user.setEmail("maria@crossfit.com");
        user.setRole(Role.ATHLETE);

        Athlete athlete = new Athlete();
        athlete.setId(7L);

        when(userRepository.findByEmail("maria@crossfit.com")).thenReturn(Optional.of(user));
        when(athleteRepository.findByUser(user)).thenReturn(Optional.of(athlete));
        when(jwtService.generateToken(user)).thenReturn("logintoken");
        RefreshToken rt = new RefreshToken();
        rt.setToken("refreshlogin");
        when(refreshTokenService.createRefreshToken(any())).thenReturn(rt);

        var loginRequest = new com.example.demo.dto.LoginRequest();
        loginRequest.setEmail("maria@crossfit.com");
        loginRequest.setPassword("pass123");

        var response = authService.login(loginRequest);

        assertThat(response.getRole()).isEqualTo("ATHLETE");
        assertThat(response.getProfileId()).isEqualTo(7L);
        assertThat(response.getToken()).isEqualTo("logintoken");
    }
}
