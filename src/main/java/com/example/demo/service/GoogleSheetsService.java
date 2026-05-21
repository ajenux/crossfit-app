package com.example.demo.service;

import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.sheets.v4.Sheets;
import com.google.api.services.sheets.v4.SheetsScopes;
import com.google.api.services.sheets.v4.model.ValueRange;
import com.google.auth.http.HttpCredentialsAdapter;
import com.google.auth.oauth2.GoogleCredentials;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.*;

@Service
public class GoogleSheetsService {

    @Value("${google.sheets.spreadsheet-id}")
    private String spreadsheetId;

    @Value("${google.credentials.json}")
    private String credentialsJson;

    public record ParsedWeek(int weekNumber, int dayCount, Map<Integer, String> dayContent) {}

    private Sheets buildClient() throws IOException, GeneralSecurityException {
        if (credentialsJson == null || credentialsJson.isBlank()) {
            throw new IllegalStateException("GOOGLE_CREDENTIALS_JSON env var is not configured");
        }
        GoogleCredentials credentials = GoogleCredentials
                .fromStream(new ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8)))
                .createScoped(List.of(SheetsScopes.SPREADSHEETS_READONLY));
        return new Sheets.Builder(
                GoogleNetHttpTransport.newTrustedTransport(),
                GsonFactory.getDefaultInstance(),
                new HttpCredentialsAdapter(credentials))
                .setApplicationName("CrossFit App")
                .build();
    }

    public List<ParsedWeek> parseWeeks() throws IOException, GeneralSecurityException {
        Sheets sheets = buildClient();
        ValueRange response = sheets.spreadsheets().values()
                .get(spreadsheetId, "A1:H600")
                .execute();
        List<List<Object>> rows = response.getValues();
        if (rows == null || rows.isEmpty()) return List.of();

        List<ParsedWeek> weeks = new ArrayList<>();
        int weekStart = -1;
        int weekNumber = 1;

        for (int i = 0; i < rows.size(); i++) {
            List<Object> row = rows.get(i);
            if (!row.isEmpty() && "Dia 1".equalsIgnoreCase(row.get(0).toString().trim())) {
                if (weekStart >= 0) {
                    weeks.add(buildWeek(rows.subList(weekStart, i), weekNumber++));
                }
                weekStart = i;
            }
        }
        if (weekStart >= 0) {
            weeks.add(buildWeek(rows.subList(weekStart, rows.size()), weekNumber));
        }
        return weeks;
    }

    private ParsedWeek buildWeek(List<List<Object>> block, int weekNumber) {
        List<Object> header = block.get(0);
        int dayCount = 0;
        for (Object cell : header) {
            if (cell.toString().trim().toLowerCase().startsWith("dia ")) dayCount++;
        }
        if (dayCount == 0) dayCount = 3;

        Map<Integer, StringBuilder> builders = new LinkedHashMap<>();
        for (int d = 1; d <= dayCount; d++) builders.put(d, new StringBuilder());

        for (int r = 1; r < block.size(); r++) {
            List<Object> row = block.get(r);
            for (int d = 1; d <= dayCount; d++) {
                int col = (d - 1) * 2;
                if (col < row.size()) {
                    String val = row.get(col).toString().trim();
                    if (!val.isEmpty()) {
                        builders.get(d).append(val).append("\n");
                    }
                }
            }
        }

        Map<Integer, String> content = new LinkedHashMap<>();
        for (int d = 1; d <= dayCount; d++) {
            content.put(d, builders.get(d).toString().trim());
        }
        return new ParsedWeek(weekNumber, dayCount, content);
    }
}