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
import java.util.regex.Pattern;

@Service
public class GoogleSheetsService {

    @Value("${google.sheets.spreadsheet-id}")
    private String spreadsheetId;

    @Value("${google.credentials.json}")
    private String credentialsJson;

    public record ParsedWeek(int weekNumber, int dayCount, Map<Integer, String> dayContent) {}

    private static final Pattern WOD_HEADER = Pattern.compile(
            ".*(amrap|emom|for time|rxt|a completar|chipper|\\d+(-\\d+){2,}).*", Pattern.CASE_INSENSITIVE);

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

    public List<String> getSheetNames() throws IOException, GeneralSecurityException {
        Sheets sheets = buildClient();
        return sheets.spreadsheets().get(spreadsheetId).execute()
                .getSheets().stream()
                .map(s -> s.getProperties().getTitle())
                .toList();
    }

    public List<ParsedWeek> parseWeeks(String sheetName) throws IOException, GeneralSecurityException {
        Sheets sheets = buildClient();
        String range = sheetName + "!A1:H600";
        ValueRange response = sheets.spreadsheets().values()
                .get(spreadsheetId, range)
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

        // Two builders per day: even col (warmup/fuerza) and odd col (WOD section).
        Map<Integer, StringBuilder> mainBuilders = new LinkedHashMap<>();
        Map<Integer, StringBuilder> wodBuilders = new LinkedHashMap<>();
        for (int d = 1; d <= dayCount; d++) {
            mainBuilders.put(d, new StringBuilder());
            wodBuilders.put(d, new StringBuilder());
        }

        for (int r = 1; r < block.size(); r++) {
            List<Object> row = block.get(r);
for (int d = 1; d <= dayCount; d++) {
                int colMain = (d - 1) * 2;
                int colWod = colMain + 1;
                if (colMain < row.size()) {
                    String val = row.get(colMain).toString().trim();
                    if (!val.isEmpty()) mainBuilders.get(d).append(val).append("\n");
                }
                if (colWod < row.size()) {
                    String val = row.get(colWod).toString().trim();
                    if (!val.isEmpty()) wodBuilders.get(d).append(val).append("\n");
                }
            }
        }

        Map<Integer, String> content = new LinkedHashMap<>();
        for (int d = 1; d <= dayCount; d++) {
            // Append odd-col content after even-col so addSectionMarkers sees the WOD section last.
            String combined = mainBuilders.get(d).toString() + wodBuilders.get(d).toString();
            content.put(d, addSectionMarkers(combined.trim()));
        }
        return new ParsedWeek(weekNumber, dayCount, content);
    }

    private String addSectionMarkers(String raw) {
        if (raw == null || raw.isBlank()) return raw;
        String[] lines = raw.split("\n");
        StringBuilder result = new StringBuilder("[WARMUP]\n");
        boolean fuerzaFound = false;
        boolean wodFound = false;

        for (String line : lines) {
            String trimmed = line.trim();
            String lower = trimmed.toLowerCase();

            if (!fuerzaFound && !wodFound && lower.equals("fuerza")) {
                fuerzaFound = true;
                result.append("[FUERZA]\n");
                continue;
            }
            if (!wodFound && WOD_HEADER.matcher(lower).matches()) {
                wodFound = true;
                result.append("[WOD]\n");
            }
            result.append(trimmed).append("\n");
        }
        return result.toString().trim();
    }
}