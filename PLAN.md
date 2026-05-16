# Project Plan — CrossFit App

Tracks what has been done, where we are, and what's next.
Updated whenever a phase is completed or started.

---

## Current status
**Active branch:** `develop`
**Last updated:** 2026-05-15
**Open PR:** `develop → master` (pending merge — user merging from GitHub UI)

---

## Done

### Base architecture
- [x] Spring Boot 4 + JPA + PostgreSQL
- [x] Flutter mobile with `go_router`, `SharedPreferences`, `http`
- [x] JWT stateless auth (register + login)
- [x] Entities: `User`, `Athlete`, `Coach`, `Workout`, `CoachAvailability`

### Authentication and users
- [x] `User` linked to `Athlete`/`Coach` via `@OneToOne` FK (`user_id`)
- [x] Registration automatically creates profile (Athlete or Coach based on role)
- [x] Login returns `{token, role, profileId}` — Flutter uses real profileId, not hardcoded
- [x] Flutter navigates to the correct dashboard based on role received at login/register

### Security
- [x] Roles: `ATHLETE`, `COACH`
- [x] `@PreAuthorize("hasRole('COACH')")` on all write endpoints
- [x] Fine-grained authorization in services: athletes can only see/modify their own data
  - Workouts: `GET /api/workouts` filters by authenticated athlete
  - Dashboard: `GET /api/dashboard/athlete/{id}` verifies ownership
- [x] `GlobalExceptionHandler` converts service-layer `AccessDeniedException` → 403
- [x] Credentials via environment variables (`.env`, not committed)

### Features
- [x] Workout CRUD with pagination (`Page<WorkoutResponse>`)
- [x] Athlete CRUD with pagination
- [x] Coach CRUD with pagination
- [x] Coach availability (`CoachAvailability`) — recurring and specific-date slots
- [x] Athlete dashboard: own workouts + assigned coach availability in one response
- [x] AI exercise assistant (`POST /api/ai/exercise`) via Ollama + ExerciseDB
- [x] Workout description generator (`POST /api/ai/generate-workout`) via Ollama
- [x] Flutter coach dashboard — Athletes tab (list + assign), Workouts tab (create + delete), Availability tab (add + delete)
- [x] Assign coach to athlete from UI — FloatingActionButton in Athletes tab
- [x] Deploy — Railway backend + Flutter web pipeline with demo environment

### Quality
- [x] 16 automated tests (4 service unit tests + 12 controller integration tests)
- [x] Fix `LazyInitializationException` in `AthleteDashboardService` (`@Transactional(readOnly=true)`)
- [x] README cleaned (no hardcoded credentials)
- [x] Duplicate Flutter folder (`crossfit_flutter/`) removed
- [x] Fix missing `ApiService` import in `mobile/lib/main.dart`
- [x] `ARCHITECTURE.md` added with full system documentation
- [x] `ApiService` refactored to use typed `ApiResult` and improved error handling
- [x] AI-assisted commit message hook (`prepare-commit-msg`) via Ollama
- [x] `CLAUDE.md` added with project instructions for Claude
- [x] Pre-push hook runs `update-plan.sh` to keep `PLAN.md` current before every push
- [x] Fix `update-plan.sh` to strip Claude explanation text from output
- [x] **Flutter: _ErrorView logout button** — added Logout option to error screens so users are not stuck in a retry loop on 403 errors

---

## Pending / Next steps

### High priority
- [ ] **Merge PR** `develop → master` — live testing confirmed everything works (user merging from GitHub UI)

### Medium priority
- [ ] **Flutter: pagination** — backend paginates but Flutter loads everything with no infinite scroll
- [ ] **Input validation** — no `@Valid` / `@NotNull` on incoming DTOs
- [ ] **Flutter tests** — only backend is tested

### Low priority / Future ideas
- [ ] **Push notifications** — alert athlete when a workout is assigned
- [ ] **Athlete progress** — history of completed vs pending workouts
- [ ] **Better AI** — more capable models or surface AI results directly in the dashboard
- [ ] **Refresh token** — JWT expires with no renewal mechanism, requires re-login

---

## Key technical decisions

| Decision | Reason |
|----------|--------|
| `@OneToOne` between `User` and `Athlete`/`Coach` | Email-only relationship was fragile; FK enforces referential integrity |
| `GlobalExceptionHandler` for 403 | Spring Security 7 does not propagate service-layer `AccessDeniedException` through `ExceptionTranslationFilter` correctly |
| `@Transactional(readOnly=true)` on `AthleteDashboardService` | Without a transaction, `WorkoutResponse` constructor cannot access lazy-loaded `Athlete` and `Coach` associations |
| `SecurityMockMvcRequestPostProcessors.user()` in tests | `@WithMockUser` does not work with Spring Boot 4's new `@AutoConfigureMockMvc` |
| Environment variables for credentials | `.env` + `.env.example` pattern, `.env` in `.gitignore` |
| Railway for backend deployment | Chosen for zero-config PostgreSQL add-on and simple Spring Boot deploy via `railway.toml` |
