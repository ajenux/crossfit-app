# Architecture — CrossFit Platform

This document explains how the system is built, why each decision was made,
and how to extend it. It is intended for any developer joining the project.

---

## Table of contents

1. [System overview](#1-system-overview)
2. [Backend — Spring Boot](#2-backend--spring-boot)
3. [Mobile — Flutter](#3-mobile--flutter)
4. [Authentication flow](#4-authentication-flow)
5. [Authorization model](#5-authorization-model)
6. [Key design decisions](#6-key-design-decisions)
7. [Multi-vertical vision](#7-multi-vertical-vision)
8. [How to add a new vertical](#8-how-to-add-a-new-vertical)
9. [Environment and configuration](#9-environment-and-configuration)
10. [Testing strategy](#10-testing-strategy)

---

## 1. System overview

```
┌─────────────────────┐        HTTP/JSON        ┌──────────────────────┐
│   Flutter mobile    │ ──────────────────────> │  Spring Boot API     │
│   (Android/iOS)     │ <────────────────────── │  (port 8080)         │
└─────────────────────┘        JWT Bearer       └──────────┬───────────┘
                                                           │ JPA/SQL
                                                ┌──────────▼───────────┐
                                                │   PostgreSQL DB       │
                                                └──────────────────────┘
                                                           │
                                                ┌──────────▼───────────┐
                                                │  Ollama (local AI)    │
                                                │  ExerciseDB (RapidAPI)│
                                                └──────────────────────┘
```

**Stack:**
- Backend: Spring Boot 4, Spring Security 7, Spring Data JPA, PostgreSQL
- Mobile: Flutter (Dart), go_router, SharedPreferences, http
- Auth: JWT (stateless, no sessions) + refresh token (DB-backed, 7-day expiry)
- AI: Anthropic Claude Haiku in production / Ollama (llama3.2) in local dev + ExerciseDB for GIFs

---

## 2. Backend — Spring Boot

### Package structure

```
com.example.demo
├── config/               ← Spring configuration beans
│   ├── SecurityConfig        - Filter chain, CORS (env-configurable origins), auth provider
│   ├── AiConfig              - Selects Anthropic or Ollama model based on ANTHROPIC_API_KEY
│   ├── UserDetailsConfig     - Loads User from DB for Spring Security
│   └── GlobalExceptionHandler- Converts exceptions to HTTP responses (403, 400, 503)
│
├── security/             ← JWT infrastructure
│   ├── JwtService            - Token generation and validation
│   ├── JwtAuthFilter         - Reads Bearer token on every request
│   └── SecurityUtils         - Static helpers: getCurrentUserEmail(), isAthlete(), isCoach()
│
├── model/                ← JPA entities (database tables)
│   ├── User                  - Authentication record (email + password + role)
│   ├── Role                  - Enum: ATHLETE, COACH
│   ├── Athlete               - Athlete profile, linked to User via @OneToOne
│   ├── Coach                 - Coach profile, linked to User via @OneToOne
│   ├── Workout               - A workout assigned to an athlete by a coach
│   ├── WorkoutType           - Enum: AMRAP, FOR_TIME, EMOM, STRENGTH, ENDURANCE
│   ├── CoachAvailability     - A time slot when a coach is available
│   └── RefreshToken          - DB-backed refresh token (UUID, user FK, expiryDate)
│
├── repository/           ← Spring Data JPA interfaces (auto-implemented)
│   ├── UserRepository
│   ├── AthleteRepository
│   ├── CoachRepository
│   ├── WorkoutRepository
│   ├── CoachAvailabilityRepository
│   └── RefreshTokenRepository
│
├── dto/                  ← Data Transfer Objects (API input/output shapes)
│   ├── LoginRequest / RegisterRequest  - @Valid annotated, all fields constrained
│   ├── AuthResponse          - Returns token + refreshToken + role + profileId
│   ├── AthleteRequest / AthleteResponse
│   ├── CoachRequest / CoachResponse
│   ├── WorkoutRequest / WorkoutResponse
│   ├── CoachAvailabilityRequest / CoachAvailabilityResponse
│   ├── SheetsImportRequest   - weekNumber, coachId, startDate, List<AthleteImport>
│   ├── SheetsImportResponse
│   └── AthleteDashboardResponse - Composite: athlete + workouts + availability
│
├── service/              ← Business logic
│   ├── AuthService           - register() and login(), creates profile on register
│   ├── RefreshTokenService   - createRefreshToken(), verifyAndGet(), deleteByUser()
│   ├── AthleteService        - CRUD with pagination, filtered by coach if requested
│   ├── CoachService          - CRUD with pagination
│   ├── WorkoutService        - CRUD + fine-grained auth (athletes see only own data)
│   ├── CoachAvailabilityService
│   ├── AthleteDashboardService - Aggregates dashboard data in one call
│   ├── AiService             - Delegates to ChatLanguageModel (Anthropic or Ollama)
│   ├── ExerciseMediaService  - Calls ExerciseDB API to fetch exercise GIFs
│   ├── GoogleSheetsService   - Reads and parses the coach's Google Sheet into week/day blocks
│   └── SheetsImportService   - Creates workouts from parsed sheet data, N athletes with configurable weight index
│
└── controller/           ← HTTP endpoints (thin layer, delegates to services)
    ├── AuthController        - POST /api/auth/register, /login, /refresh, /logout
    ├── AthleteController     - GET/POST/PUT/DELETE /api/athletes
    ├── CoachController       - GET/POST/PUT/DELETE /api/coaches
    ├── WorkoutController     - GET/POST/PUT/DELETE /api/workouts
    ├── CoachAvailabilityController - POST/GET/DELETE /api/availability
    ├── AthleteDashboardController  - GET /api/dashboard/athlete/{id}
    ├── AiController          - POST /api/ai/exercise, POST /api/ai/generate-workout
    └── SheetsController      - GET /api/sheets/weeks, POST /api/sheets/import
```

### Request lifecycle

```
HTTP Request
   │
   ▼
JwtAuthFilter.doFilter()
   ├── Reads "Authorization: Bearer <token>" header
   ├── Validates token with JwtService
   ├── Loads User from DB (UserDetailsConfig)
   ├── Sets Authentication in SecurityContextHolder
   │
   ▼
SecurityFilterChain
   ├── /api/auth/login, /register, /refresh, /logout → permitAll
   └── all others   → authenticated
   │
   ▼
Controller method
   ├── @PreAuthorize("hasRole('COACH')") → checked here for write endpoints
   │
   ▼
Service method
   ├── SecurityUtils.isAthlete() → fine-grained checks here
   ├── throws AccessDeniedException if unauthorized
   │
   ▼
GlobalExceptionHandler
   ├── AccessDeniedException      → 403 Forbidden
   ├── MethodArgumentNotValidException → 400 Bad Request (field errors)
   └── AiUnavailableException     → 503 Service Unavailable
```

### Database schema (key relationships)

```
users (id, email, password, role)
  │
  ├── athletes (id, name, email, user_id FK, coach_id FK)
  │
  ├── coaches  (id, name, email, user_id FK)
  │                 │
  │                 └── coach_availability (id, coach_id FK, day_of_week,
  │                                        specific_date, start_time, end_time, recurring)
  │
  └── refresh_tokens (id, token UUID, user_id FK, expiry_date)

workouts (id, name, description, type, scheduled_date, athlete_id FK, coach_id FK)
```

**Why `user_id` FK on Athlete/Coach?**
Initially the link was only by matching email strings — fragile and error-prone.
The `@OneToOne` FK guarantees referential integrity: you cannot have an athlete
without a valid user record, and deleting the user cascades correctly.

---

## 3. Mobile — Flutter

### File structure

```
mobile/lib/
├── main.dart                  ← App entry point, GoRouter route definitions
├── services/
│   ├── api_client.dart        ← ApiResult<T>, token storage, HTTP wrappers with 401 retry
│   ├── auth_service.dart      ← login(), register(), logout()
│   ├── athlete_service.dart   ← getAllAthletes(), getAthletesByCoach(), assignAthleteToCoach()
│   ├── workout_service.dart   ← getWorkoutsByCoach(), createWorkout(), deleteWorkout()
│   ├── availability_service.dart ← getCoachAvailability(), addAvailability(), deleteAvailability()
│   ├── sheets_service.dart    ← getSheetWeeks(), importSheetWeek()
│   ├── ai_service.dart        ← explainExercise()
│   └── dashboard_service.dart ← getAthleteDashboard()
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── athlete/
    │   ├── athlete_dashboard_screen.dart
    │   └── exercise_assistant_screen.dart
    └── coach/
        └── coach_dashboard_screen.dart  ← 4 tabs: Athletes, Workouts, Availability, Import
```

### Navigation (go_router)

```
/login          → LoginScreen
/register       → RegisterScreen
/athlete/:id    → AthleteDashboardScreen
/coach/:id      → CoachDashboardScreen (tabs: Athletes | Workouts | Availability)
/exercise       → ExerciseAssistantScreen
```

After login/register, the backend returns `role` and `profileId`.
The app navigates to `/athlete/{profileId}` or `/coach/{profileId}` accordingly.
No hardcoded IDs anywhere.

### ApiResult<T> — error handling pattern

Every API call returns `ApiResult<T>` instead of nullable data:

```dart
class ApiResult<T> {
  final T? data;
  final int statusCode;   // 0 = network error, 401, 403, 200, etc.

  bool get isSuccess      => statusCode >= 200 && statusCode < 300;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden    => statusCode == 403;
  bool get isNetworkError => statusCode == 0;
  String get errorMessage => ...;  // Human-readable message for each case
}
```

Each screen checks the result and handles each case:
- `isUnauthorized` → clear token + navigate to login (session expired)
- `isForbidden` → show permission error message
- `isNetworkError` → show connection error + retry button
- `!isSuccess` → show generic error + retry button

---

## 4. Authentication flow

```
Register / Login:
  Client → POST /api/auth/register or /login {email, password, ...}
         ← 200 {token, refreshToken, role, profileId}
  Server: creates/validates user, generates access token (1h) + refresh token (7d, stored in DB)
  Client: saves token + refreshToken + role + profileId to SharedPreferences
          navigates to /athlete/{id} or /coach/{id}

Every subsequent request:
  Client → any endpoint with header: Authorization: Bearer <token>
  Server: JwtAuthFilter validates token, loads user, sets SecurityContext

When access token expires (401 response):
  ApiClient detects 401 → POST /api/auth/refresh {refreshToken}
         ← 200 {token, refreshToken, role, profileId}  (new tokens)
  Client: saves new tokens, retries original request transparently
  If refresh also fails: clear all tokens + redirect to login

Logout:
  Client → POST /api/auth/logout {refreshToken}
  Server: deletes refresh token from DB
  Client: clears all local storage
```

**Token storage:** SharedPreferences (device local storage).
**Access token expiry:** 1 hour (`jwt.expiration-ms=3600000`).
**Refresh token expiry:** 7 days (`jwt.refresh-expiration-days=7`), stored in `refresh_tokens` table.

---

## 5. Authorization model

Two roles: `ATHLETE` and `COACH`.

| Action | ATHLETE | COACH |
|--------|---------|-------|
| Read own workouts | ✅ | ✅ (all) |
| Read other athlete's workouts | ❌ 403 | ✅ |
| Create / edit / delete workouts | ❌ 403 | ✅ |
| Read athlete list | ❌ 403 | ✅ |
| Read own dashboard | ✅ | ✅ |
| Read other athlete's dashboard | ❌ 403 | ✅ |
| Manage availability | ❌ 403 | ✅ |

**Two-layer enforcement:**
1. **Controller layer** — `@PreAuthorize("hasRole('COACH')")` blocks non-coaches before the method runs
2. **Service layer** — `SecurityUtils.isAthlete()` + ownership checks block athletes from other athletes' data

Both layers are needed: `@PreAuthorize` handles role-level access, service checks handle data-level access.

---

## 6. Key design decisions

### Why @OneToOne between User and Athlete/Coach?
The original design linked them only by matching email strings. This breaks if an email changes and creates orphaned data. The FK (`user_id`) makes the relationship explicit, enforced at the database level, and navigable via JPA.

### Why GlobalExceptionHandler for AccessDeniedException?
Spring Security 7 changed how it handles exceptions. `AccessDeniedException` thrown from a **service method** (not a filter) is not caught by `ExceptionTranslationFilter` when the user is already authenticated — it was returning 403 in some cases and 500 in others. The `@RestControllerAdvice` handler catches it reliably and always returns a proper 403 with the error message.

### Why @Transactional(readOnly=true) on AthleteDashboardService?
`WorkoutResponse` accesses `workout.getAthlete().getName()` and `workout.getCoach().getName()`. These are lazy-loaded associations. Without a transaction open when the response is built, JPA throws `LazyInitializationException`. The `@Transactional` keeps the JPA session open for the entire service method execution.

### Why stateless JWT instead of sessions?
Sessions require shared state between server restarts and don't scale horizontally. JWT is self-contained — the server only needs the secret key to validate any token, no database lookup required per request.

### Why ApiResult<T> in Flutter instead of exceptions?
Flutter's `async/await` with try/catch for every API call creates noisy code. `ApiResult<T>` makes error handling explicit and uniform — every caller knows it must handle `isSuccess`, `isUnauthorized`, and `isNetworkError`. It also avoids the problem of swallowed exceptions in async code.

---

## 7. Multi-vertical vision

The current codebase targets CrossFit gyms. The goal is to evolve it into a
**platform** that supports multiple business verticals (CrossFit, tattoo studio,
medical clinic, etc.) while sharing as much infrastructure as possible.

### What is already reusable (core)

| Component | Why it's reusable |
|-----------|-------------------|
| `User` entity + JWT auth | Any app needs users and login |
| `Role` enum + Spring Security config | Role-based access is universal |
| `JwtService` / `JwtAuthFilter` | Token logic is domain-agnostic |
| `SecurityUtils` | Helper for any role-based service |
| `GlobalExceptionHandler` | Exception mapping is universal |
| `CoachAvailability` pattern | Any business has "provider availability" |
| `ApiResult<T>` in Flutter | Error handling pattern for any API |
| `_ErrorView` widget in Flutter | Reusable across all verticals |

### What changes per vertical

| Component | CrossFit | Tattoo Studio | Medical Clinic |
|-----------|----------|---------------|----------------|
| Roles | ATHLETE / COACH | CLIENT / ARTIST | PATIENT / DOCTOR |
| Domain entity | Workout | Appointment | Consultation |
| Domain types | AMRAP, EMOM... | Flash, Custom... | Checkup, Surgery... |
| Dashboard | Workouts + availability | Booking history | Appointment calendar |
| AI integration | Exercise assistant | Style recommender | Symptom checker |

### Proposed modular structure (next evolution)

**Backend:**
```
com.platform
├── core/                     ← shared, never vertical-specific
│   ├── auth/                     User, Role, JWT, AuthService, AuthController
│   ├── scheduling/               Availability model (provider + time slots)
│   ├── profile/                  Base profile pattern (User → Profile @OneToOne)
│   └── common/                   GlobalExceptionHandler, SecurityUtils, ApiResult
│
├── crossfit/                 ← this vertical
│   ├── athlete/                  Athlete, AthleteService, AthleteController
│   ├── coach/                    Coach, CoachService, CoachController
│   ├── workout/                  Workout, WorkoutType, WorkoutService, WorkoutController
│   └── dashboard/                AthleteDashboardService, AthleteDashboardController
│
└── tattoo/                   ← future vertical (example)
    ├── client/
    ├── artist/
    └── appointment/
```

**Flutter:**
```
lib/
├── core/                     ← shared
│   ├── services/api_service.dart     ApiResult<T>, auth, token storage
│   ├── widgets/error_view.dart       _ErrorView (currently duplicated)
│   └── router.dart                   GoRouter config
│
├── crossfit/                 ← this vertical
│   └── screens/...
│
└── tattoo/                   ← future vertical
    └── screens/...
```

### Migration path (no big bang rewrite)

The current code does not need to be rewritten to move toward this structure.
The migration can happen incrementally:

1. Move `config/`, `security/` → `core/` package (rename only, no logic change)
2. Move `model/User`, `model/Role` → `core/auth/`
3. Move `model/CoachAvailability` → `core/scheduling/` (rename `Coach` references to generic `Provider`)
4. What remains in `com.example.demo` becomes the `crossfit/` vertical
5. When adding a new vertical, add a new package alongside `crossfit/`

This means a new developer adding a tattoo studio module would:
- Import `core/` (auth, scheduling, profile pattern)
- Add `tattoo/` package with their own entities and business rules
- Reuse 100% of the auth and availability infrastructure

---

## 8. How to add a new vertical

### Backend steps

1. Create package `com.platform.<vertical>/`
2. Define your domain entity (e.g., `Appointment`), extending the profile pattern:
   ```java
   @Entity
   public class Artist {
       @Id @GeneratedValue
       private Long id;
       private String name;
       private String email;

       @OneToOne(fetch = FetchType.LAZY)
       @JoinColumn(name = "user_id", unique = true)
       private User user;   // ← always link to User, never store credentials here
   }
   ```
3. Add the new role to the `Role` enum: `ARTIST`
4. Update `AuthService.createProfile()` to handle the new role
5. Add your service, controller, and DTOs following the same pattern

### Flutter steps

1. Create `lib/<vertical>/screens/`
2. Add routes in `main.dart` for the new role
3. Update the post-login navigation in `login_screen.dart` and `register_screen.dart`
4. All API calls use the existing `ApiResult<T>` — no changes needed there

### What you get for free
- JWT auth (login, register, token validation)
- Role-based access control (just add the role to the enum)
- Error handling in Flutter (ApiResult<T>)
- CORS configuration
- Exception → HTTP status mapping

---

## 9. Environment and configuration

Sensitive values are **never hardcoded**. They live in a `.env` file (not committed to git).

```bash
# .env (local only — see .env.example for the template)
DB_USERNAME=crossfit_user
DB_PASSWORD=your_db_password
JWT_SECRET=your_jwt_secret_min_32_chars
EXERCISEDB_API_KEY=your_rapidapi_key          # optional, AI still works without it
GOOGLE_CREDENTIALS_JSON={"type":"service_account",...}  # Google Sheets service account (single line JSON)
ANTHROPIC_API_KEY=sk-ant-...                  # optional; if absent, falls back to Ollama locally
CORS_ALLOWED_ORIGINS=http://localhost:3000    # in production: https://ajenux.github.io
OLLAMA_BASE_URL=http://localhost:11434        # only used when ANTHROPIC_API_KEY is not set
```

`application.properties` reads these via Spring's `${VAR:default}` syntax:
```properties
spring.datasource.username=${DB_USERNAME:crossfit_user}
spring.datasource.password=${DB_PASSWORD}
jwt.secret=${JWT_SECRET}
jwt.expiration-ms=3600000          # 1 hour (access token)
jwt.refresh-expiration-days=7      # 7 days (refresh token)
cors.allowed-origins=${CORS_ALLOWED_ORIGINS:http://localhost:3000,...}
anthropic.api.key=${ANTHROPIC_API_KEY:}
ollama.base-url=${OLLAMA_BASE_URL:http://localhost:11434}
```

**To load the variables before starting the server:**
```bash
export $(cat .env | xargs) && ./mvnw spring-boot:run
```

**Flutter base URL** is injected at build time via `--dart-define=API_URL=https://...`.
Default in `api_client.dart`: `http://10.0.2.2:8080/api` (Android emulator).
For iOS simulator: `--dart-define=API_URL=http://localhost:8080/api`.

---

## 10. Testing strategy

### Backend tests

Located in `src/test/java/com/example/demo/`.

**Unit tests** (Mockito, no Spring context):
- `AuthServiceTest` — register and login logic, profile creation
- `AthleteServiceTest` — CRUD, pagination, coach filtering

**Integration tests** (full Spring context + MockMvc):
- `AuthControllerTest` — register and login HTTP endpoints
- `WorkoutControllerTest` — role-based access, athlete data isolation

**Key Spring Boot 4 differences** (different from SB3 tutorials online):
- Use `@SpringBootTest` + `@AutoConfigureMockMvc` — `@WebMvcTest` does not exist in SB4
- Use `@MockitoBean` — `@MockBean` does not exist in SB4
- Use `SecurityMockMvcRequestPostProcessors.user()` directly in each request — `@WithMockUser` does not work with SB4's new `@AutoConfigureMockMvc`
- Import from `org.springframework.boot.webmvc.test.autoconfigure` (new package in SB4)

**To run tests:**
```bash
export $(cat .env | xargs) && ./mvnw test
```

### Flutter tests
Not yet implemented. The existing `test/widget_test.dart` is the default Flutter placeholder.
Future tests should use `flutter_test` with mocked service classes (e.g. mock `AthleteService`, `WorkoutService`).

---

## Developer setup

### Backend
```bash
# 1. Copy .env.example to .env and fill in values
cp .env.example .env

# 2. Start PostgreSQL and create the database
createdb crossfit_db

# 3. Load env vars and start the server
export $(cat .env | xargs) && ./mvnw spring-boot:run
```

### Mobile
```bash
cd mobile
flutter pub get

# Android emulator (default):
flutter run

# iOS simulator:
flutter run --dart-define=API_URL=http://localhost:8080/api

# Against production backend:
flutter run --dart-define=API_URL=https://crossfit-app-production-fcf2.up.railway.app/api
```

### Git hooks (run once after cloning)
```bash
./scripts/setup-hooks.sh
```
This activates:
- `prepare-commit-msg` — auto-generates commit messages using Claude CLI when you run `git commit`

To update `PLAN.md` manually before a push:
```bash
./scripts/update-plan.sh && git add PLAN.md && git commit --amend --no-edit
```
