package com.example.demo.controller;

import com.example.demo.dto.AuthResponse;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import com.example.demo.repository.UserRepository;
import com.example.demo.security.JwtService;
import com.example.demo.security.LoginRateLimitFilter;
import com.example.demo.service.AuthService;
import com.example.demo.service.AuthService.EmailNotVerifiedException;
import com.example.demo.service.PasswordResetService.InvalidTokenException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;

import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class AuthControllerTest {

    @Autowired MockMvc mockMvc;
    @Autowired LoginRateLimitFilter rateLimitFilter;

    @MockitoBean AuthService authService;
    @MockitoBean JwtService jwtService;
    @MockitoBean UserRepository userRepository;
    @MockitoBean AthleteRepository athleteRepository;
    @MockitoBean CoachRepository coachRepository;
    @MockitoBean AuthenticationManager authenticationManager;

    @BeforeEach
    void resetBuckets() {
        rateLimitFilter.clearBuckets();
    }

    @Test
    void register_validRequest_returnsOkWithoutTokens() throws Exception {
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"name":"Maria","email":"maria@x.com","password":"password123","role":"ATHLETE"}
                        """))
                .andExpect(status().isOk());

        verify(authService).register(any());
    }

    @Test
    void login_validCredentials_returnsToken() throws Exception {
        when(authService.login(any()))
                .thenReturn(new AuthResponse("tok456", "refresh456", "COACH", 2L));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"email":"juan@x.com","password":"password123"}
                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("tok456"))
                .andExpect(jsonPath("$.role").value("COACH"))
                .andExpect(jsonPath("$.profileId").value(2));
    }

    @Test
    void forgotPassword_returnsOkRegardlessOfEmailExisting() throws Exception {
        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"email":"anyone@x.com"}
                        """))
                .andExpect(status().isOk());

        verify(authService).forgotPassword("anyone@x.com");
    }

    @Test
    void resetPassword_validToken_returnsOk() throws Exception {
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"token":"reset-abc","newPassword":"newpassword123"}
                        """))
                .andExpect(status().isOk());

        verify(authService).resetPassword("reset-abc", "newpassword123");
    }

    @Test
    void resetPassword_invalidToken_returnsBadRequest() throws Exception {
        doThrow(new InvalidTokenException("Invalid or already used reset link"))
                .when(authService).resetPassword(anyString(), anyString());

        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"token":"bad-token","newPassword":"newpassword123"}
                        """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void verifyEmail_validToken_returnsOk() throws Exception {
        mockMvc.perform(post("/api/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"token":"verify-abc"}
                        """))
                .andExpect(status().isOk());

        verify(authService).verifyEmail("verify-abc");
    }

    @Test
    void resendVerification_returnsOkRegardlessOfEmailExisting() throws Exception {
        mockMvc.perform(post("/api/auth/resend-verification")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"email":"anyone@x.com"}
                        """))
                .andExpect(status().isOk());

        verify(authService).resendVerification("anyone@x.com");
    }

    @Test
    void login_unverifiedEmail_returnsForbidden() throws Exception {
        when(authService.login(any()))
                .thenThrow(new EmailNotVerifiedException("Please verify your email before logging in"));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"email":"unverified@x.com","password":"password123"}
                        """))
                .andExpect(status().isForbidden());
    }
}
