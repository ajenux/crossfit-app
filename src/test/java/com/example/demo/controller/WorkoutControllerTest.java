package com.example.demo.controller;

import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import com.example.demo.repository.UserRepository;
import com.example.demo.security.JwtService;
import com.example.demo.service.WorkoutService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.data.domain.Page;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class WorkoutControllerTest {

    @Autowired MockMvc mockMvc;

    @MockitoBean WorkoutService workoutService;
    @MockitoBean JwtService jwtService;
    @MockitoBean UserRepository userRepository;
    @MockitoBean AthleteRepository athleteRepository;
    @MockitoBean CoachRepository coachRepository;
    @MockitoBean AuthenticationManager authenticationManager;
    @MockitoBean UserDetailsService userDetailsService;

    private static final String WORKOUT_JSON = """
            {
              "name": "Fran",
              "description": "21-15-9",
              "type": "FOR_TIME",
              "scheduledDate": "2026-05-10",
              "athleteId": 1,
              "coachId": 1
            }
            """;

    @Test
    void createWorkout_unauthenticated_returns401() throws Exception {
        mockMvc.perform(post("/api/workouts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(WORKOUT_JSON))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void createWorkout_asAthlete_returns403() throws Exception {
        mockMvc.perform(post("/api/workouts")
                        .with(user("maria").roles("ATHLETE"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(WORKOUT_JSON))
                .andExpect(status().isForbidden());
    }

    @Test
    void getWorkouts_asCoach_returns200() throws Exception {
        when(workoutService.findAll(any())).thenReturn(Page.empty());

        mockMvc.perform(get("/api/workouts")
                        .with(user("juan").roles("COACH")))
                .andExpect(status().isOk());
    }

    @Test
    void getWorkouts_asAthlete_returns200() throws Exception {
        when(workoutService.findByAthlete(any(), any())).thenReturn(Page.empty());

        mockMvc.perform(get("/api/workouts?athleteId=1")
                        .with(user("maria").roles("ATHLETE")))
                .andExpect(status().isOk());
    }

    @Test
    void getWorkouts_unauthenticated_returns401() throws Exception {
        mockMvc.perform(get("/api/workouts"))
                .andExpect(status().isUnauthorized());
    }
}
