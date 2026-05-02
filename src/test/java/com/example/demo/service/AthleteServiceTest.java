package com.example.demo.service;

import com.example.demo.dto.AthleteRequest;
import com.example.demo.dto.AthleteResponse;
import com.example.demo.model.Athlete;
import com.example.demo.model.Coach;
import com.example.demo.repository.AthleteRepository;
import com.example.demo.repository.CoachRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AthleteServiceTest {

    @Mock AthleteRepository athleteRepository;
    @Mock CoachRepository coachRepository;

    @InjectMocks AthleteService athleteService;

    @Test
    void findAll_returnsPaginatedAthletes() {
        Coach coach = new Coach();
        coach.setId(1L);
        coach.setName("Coach");

        Athlete a1 = new Athlete(); a1.setId(1L); a1.setName("Maria"); a1.setEmail("maria@x.com"); a1.setCoach(coach);
        Athlete a2 = new Athlete(); a2.setId(2L); a2.setName("Pedro"); a2.setEmail("pedro@x.com"); a2.setCoach(coach);

        PageRequest pageable = PageRequest.of(0, 10);
        when(athleteRepository.findAll(pageable)).thenReturn(new PageImpl<>(List.of(a1, a2)));

        Page<AthleteResponse> result = athleteService.findAll(pageable);

        assertThat(result.getTotalElements()).isEqualTo(2);
        assertThat(result.getContent()).extracting(AthleteResponse::getName)
                .containsExactly("Maria", "Pedro");
    }

    @Test
    void create_duplicateEmail_throwsException() {
        when(athleteRepository.existsByEmail("maria@x.com")).thenReturn(true);

        AthleteRequest request = new AthleteRequest();
        request.setEmail("maria@x.com");
        request.setName("Maria");
        request.setCoachId(1L);

        assertThatThrownBy(() -> athleteService.create(request))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("Email already in use");
    }

    @Test
    void create_coachNotFound_throwsException() {
        when(athleteRepository.existsByEmail(any())).thenReturn(false);
        when(coachRepository.findById(99L)).thenReturn(Optional.empty());

        AthleteRequest request = new AthleteRequest();
        request.setEmail("new@x.com");
        request.setName("New");
        request.setCoachId(99L);

        assertThatThrownBy(() -> athleteService.create(request))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("Coach not found");
    }

    @Test
    void findById_notFound_throwsException() {
        when(athleteRepository.findById(999L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> athleteService.findById(999L))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("Athlete not found");
    }
}
