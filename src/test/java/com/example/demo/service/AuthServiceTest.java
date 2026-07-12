package com.example.demo.service;

import com.example.demo.dto.RegisterRequest;
import com.example.demo.model.Athlete;
import com.example.demo.model.Coach;
import com.example.demo.model.EmailVerificationToken;
import com.example.demo.model.PasswordResetToken;
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
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
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
    @Mock PasswordResetService passwordResetService;
    @Mock EmailVerificationService emailVerificationService;
    @Mock EmailService emailService;

    @InjectMocks AuthService authService;

    @BeforeEach
    void setFrontendUrl() {
        ReflectionTestUtils.setField(authService, "frontendUrl", "https://ajenux.github.io/crossfit-app");
    }

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
    void register_athlete_createsUnverifiedUserAndSendsVerificationEmail() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(passwordEncoder.encode(anyString())).thenReturn("encoded");
        when(userRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        Athlete savedAthlete = new Athlete();
        savedAthlete.setId(5L);
        when(athleteRepository.save(any())).thenReturn(savedAthlete);
        EmailVerificationToken verificationToken = new EmailVerificationToken();
        verificationToken.setToken("verify-abc");
        when(emailVerificationService.createToken(any())).thenReturn(verificationToken);

        authService.register(athleteRequest);

        var userCaptor = org.mockito.ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        assertThat(userCaptor.getValue().isEmailVerified()).isFalse();
        verify(emailService).sendVerificationEmail(
                "maria@crossfit.com",
                "https://ajenux.github.io/crossfit-app/#/verify-email?token=verify-abc");
    }

    @Test
    void register_coach_createsUnverifiedUserAndSendsVerificationEmail() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(passwordEncoder.encode(anyString())).thenReturn("encoded");
        when(userRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        Coach savedCoach = new Coach();
        savedCoach.setId(3L);
        when(coachRepository.save(any())).thenReturn(savedCoach);
        EmailVerificationToken verificationToken = new EmailVerificationToken();
        verificationToken.setToken("verify-def");
        when(emailVerificationService.createToken(any())).thenReturn(verificationToken);

        authService.register(coachRequest);

        verify(emailService).sendVerificationEmail(
                "juan@crossfit.com",
                "https://ajenux.github.io/crossfit-app/#/verify-email?token=verify-def");
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
        user.setEmailVerified(true);

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

    @Test
    void login_unverifiedEmail_throwsException() {
        User user = new User();
        user.setEmail("maria@crossfit.com");
        user.setRole(Role.ATHLETE);
        user.setEmailVerified(false);

        when(userRepository.findByEmail("maria@crossfit.com")).thenReturn(Optional.of(user));

        var loginRequest = new com.example.demo.dto.LoginRequest();
        loginRequest.setEmail("maria@crossfit.com");
        loginRequest.setPassword("pass123");

        assertThatThrownBy(() -> authService.login(loginRequest))
                .isInstanceOf(AuthService.EmailNotVerifiedException.class)
                .hasMessageContaining("verify your email");

        verify(jwtService, never()).generateToken(any());
    }

    @Test
    void forgotPassword_existingEmail_createsTokenAndSendsEmail() {
        User user = new User();
        user.setEmail("maria@crossfit.com");
        when(userRepository.findByEmail("maria@crossfit.com")).thenReturn(Optional.of(user));

        PasswordResetToken resetToken = new PasswordResetToken();
        resetToken.setToken("reset-abc");
        when(passwordResetService.createToken(user)).thenReturn(resetToken);

        authService.forgotPassword("maria@crossfit.com");

        verify(emailService).sendPasswordResetEmail(
                "maria@crossfit.com",
                "https://ajenux.github.io/crossfit-app/#/reset-password?token=reset-abc");
    }

    @Test
    void forgotPassword_unknownEmail_doesNothing() {
        when(userRepository.findByEmail("ghost@crossfit.com")).thenReturn(Optional.empty());

        authService.forgotPassword("ghost@crossfit.com");

        verify(passwordResetService, never()).createToken(any());
        verify(emailService, never()).sendPasswordResetEmail(anyString(), anyString());
    }

    @Test
    void resetPassword_validToken_updatesPasswordAndClearsRefreshTokens() {
        User user = new User();
        user.setEmail("maria@crossfit.com");
        when(passwordResetService.verifyAndConsume("reset-abc")).thenReturn(user);
        when(passwordEncoder.encode("newpass123")).thenReturn("encoded-newpass");

        authService.resetPassword("reset-abc", "newpass123");

        assertThat(user.getPassword()).isEqualTo("encoded-newpass");
        verify(userRepository).save(user);
        verify(refreshTokenService).deleteByUser(user);
    }

    @Test
    void resendVerification_unverifiedExistingEmail_createsTokenAndSendsEmail() {
        User user = new User();
        user.setEmail("maria@crossfit.com");
        user.setEmailVerified(false);
        when(userRepository.findByEmail("maria@crossfit.com")).thenReturn(Optional.of(user));

        EmailVerificationToken verificationToken = new EmailVerificationToken();
        verificationToken.setToken("verify-xyz");
        when(emailVerificationService.createToken(user)).thenReturn(verificationToken);

        authService.resendVerification("maria@crossfit.com");

        verify(emailService).sendVerificationEmail(
                "maria@crossfit.com",
                "https://ajenux.github.io/crossfit-app/#/verify-email?token=verify-xyz");
    }

    @Test
    void resendVerification_alreadyVerifiedEmail_doesNothing() {
        User user = new User();
        user.setEmail("maria@crossfit.com");
        user.setEmailVerified(true);
        when(userRepository.findByEmail("maria@crossfit.com")).thenReturn(Optional.of(user));

        authService.resendVerification("maria@crossfit.com");

        verify(emailVerificationService, never()).createToken(any());
        verify(emailService, never()).sendVerificationEmail(anyString(), anyString());
    }

    @Test
    void resendVerification_unknownEmail_doesNothing() {
        when(userRepository.findByEmail("ghost@crossfit.com")).thenReturn(Optional.empty());

        authService.resendVerification("ghost@crossfit.com");

        verify(emailVerificationService, never()).createToken(any());
        verify(emailService, never()).sendVerificationEmail(anyString(), anyString());
    }

    @Test
    void verifyEmail_validToken_marksUserVerified() {
        User user = new User();
        user.setEmail("maria@crossfit.com");
        user.setEmailVerified(false);
        when(emailVerificationService.verifyAndConsume("verify-abc")).thenReturn(user);

        authService.verifyEmail("verify-abc");

        assertThat(user.isEmailVerified()).isTrue();
        verify(userRepository).save(user);
    }
}
