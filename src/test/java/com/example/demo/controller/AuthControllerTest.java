package com.example.demo.controller;

import com.example.demo.dto.AuthResponse;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import com.example.demo.repository.UserRepository;
import com.example.demo.security.JwtService;
import com.example.demo.service.AuthService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;

import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class AuthControllerTest {

    @Autowired MockMvc mockMvc;

    @MockitoBean AuthService authService;
    @MockitoBean JwtService jwtService;
    @MockitoBean UserRepository userRepository;
    @MockitoBean AthleteRepository athleteRepository;
    @MockitoBean CoachRepository coachRepository;
    @MockitoBean AuthenticationManager authenticationManager;

    @Test
    void register_returnsTokenRoleAndProfileId() throws Exception {
        when(authService.register(any()))
                .thenReturn(new AuthResponse("tok123", "ATHLETE", 5L));

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"name":"Maria","email":"maria@x.com","password":"pass","role":"ATHLETE"}
                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("tok123"))
                .andExpect(jsonPath("$.role").value("ATHLETE"))
                .andExpect(jsonPath("$.profileId").value(5));
    }

    @Test
    void login_validCredentials_returnsToken() throws Exception {
        when(authService.login(any()))
                .thenReturn(new AuthResponse("tok456", "COACH", 2L));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                            {"email":"juan@x.com","password":"pass"}
                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("tok456"))
                .andExpect(jsonPath("$.role").value("COACH"))
                .andExpect(jsonPath("$.profileId").value(2));
    }
}
