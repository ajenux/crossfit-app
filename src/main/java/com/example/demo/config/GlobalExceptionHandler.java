package com.example.demo.config;

import com.example.demo.service.AiService.AiUnavailableException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(AccessDeniedException.class)
    public ProblemDetail handleAccessDenied(AccessDeniedException ex) {
        ProblemDetail detail = ProblemDetail.forStatus(HttpStatus.FORBIDDEN);
        detail.setDetail(ex.getMessage());
        return detail;
    }

    @ExceptionHandler(AiUnavailableException.class)
    public ProblemDetail handleAiUnavailable(AiUnavailableException ex) {
        ProblemDetail detail = ProblemDetail.forStatus(HttpStatus.SERVICE_UNAVAILABLE);
        detail.setDetail(ex.getMessage());
        return detail;
    }
}
