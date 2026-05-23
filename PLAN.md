# Project Plan — CrossFit App

Tracks what has been done, where we are, and what's next.
Updated whenever a phase is completed or started.

---

## Current status
**Active branch:** `develop`
**Last updated:** 2026-05-23 (session 3)
**Production:**
- Backend: `https://crossfit-app-production-fcf2.up.railway.app` (Railway + PostgreSQL)
- Frontend: `https://ajenux.github.io/crossfit-app` (GitHub Pages, auto-deploy on push to master)
- Full flow tested and working: register, login, assign athlete, create workout, athlete dashboard

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
- [x] **JWT refresh token** — access token reduced to 1h, refresh token expires in 7 days

### Security
- [x] Roles: `ATHLETE`, `COACH`
- [x] `@PreAuthorize("hasRole('COACH')")` on all write endpoints
- [x] Fine-grained authorization in services: athletes can only see/modify their own data
  - Workouts: `GET /api/workouts` filters by authenticated athlete
  - Dashboard: `GET /api/dashboard/athlete/{id}` verifies ownership
- [x] `GlobalExceptionHandler` converts service-layer `AccessDeniedException` → 403
- [x] Credentials via environment variables (`.env`, not committed)
- [x] **CORS restricted** — `ALLOWED_ORIGINS` environment variable controls allowed origins; restricted to `https://ajenux.github.io` in production

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
- [x] Deploy — Railway backend + Flutter web pipeline via GitHub Pages with demo environment
- [x] **Google Sheets integration** — imports training plans from coach's sheet and assigns them automatically
  - Sheet ID: `1LUksfUebyzp2ZeplLAFEmOlvwbgBOOlw25JU7ivbUgk`
  - Service Account: `crossfit-sheets@crossfit-app-496502.iam.gserviceaccount.com`
  - `GOOGLE_CREDENTIALS_JSON` configured in Railway and in `.env` local
  - Endpoints: `GET /api/sheets/weeks`, `POST /api/sheets/import`
  - Flutter: tab "Import" in coach dashboard — select week, N athletes with configurable weight index, start date
  - Weights `(X/Y/...)` are automatically split per athlete based on configurable weight column index
- [x] **AI provider configurable** — Anthropic (Claude) in production, Ollama in local development; switched via environment variable

### Quality
- [x] 16 automated tests (4 service unit tests + 12 controller integration tests)
- [x] Fix `LazyInitializationException` in `AthleteDashboardService` (`@Transactional(readOnly=true)`)
- [x] README cleaned (no hardcoded credentials)
- [x] Duplicate Flutter folder (`crossfit_flutter/`) removed
- [x] Fix missing `ApiService` import in `mobile/lib/main.dart`
- [x] `ARCHITECTURE.md` added with full system documentation
- [x] `ApiService` refactored to use typed `ApiResult` and improved error handling
- [x] **ApiService split** — god class broken into feature-specific services
- [x] AI-assisted commit message hook (`prepare-commit-msg`) via Ollama
- [x] `CLAUDE.md` added with project instructions for Claude
- [x] Pre-push hook runs `update-plan.sh` to keep `PLAN.md` current before every push
- [x] Fix `update-plan.sh` to strip Claude explanation text from output
- [x] Fix pre-push hook to amend last commit instead of creating a new one
- [x] Remove auto-commit from pre-push hook
- [x] **Flutter: _ErrorView logout button** — added Logout option to error screens so users are not stuck in a retry loop on 403 errors
- [x] **Flutter: Athletes tab FAB fix** — FAB now visible even when the athlete list is empty, so coaches can assign athletes without needing existing entries
- [x] **Input validation** — `@Valid` / `@NotNull` added to all request DTOs and controllers
- [x] **Rate limiting on login** — Bucket4j, 5 attempts/min per IP, returns 429 + `Retry-After: 60`; respects `X-Forwarded-For` for Railway proxy
- [x] **Flutter: infinite scroll pagination** — Athletes and Workouts tabs load pages of 20; `ScrollController` fetches next page 200px before bottom; pull-to-refresh resets to page 0
- [x] **Flutter tests** — 16 tests: 4 widget tests (login screen render, invalid credentials, network error, navigation) + 12 service unit tests (`AthleteService`, `WorkoutService`) via injectable `MockClient`
- [x] **Fix broken tests after JWT refresh** — `AuthServiceTest` (missing `@Mock RefreshTokenService`) and `AuthControllerTest` (`AuthResponse` constructor mismatch) repaired
- [x] **In-app notifications** — bell icon with unread badge on athlete dashboard; `Notification` entity + `GET /api/notifications` + `PUT /api/notifications/read`; `WorkoutService.create()` fires notification on assignment; bulk Sheets import does not trigger per-workout notifications

---

## Pending / Next steps

### Low priority / Future ideas
- [ ] **Athlete progress** — history of completed vs pending workouts
- [ ] **Better AI** — more capable models or surface AI results directly in the dashboard

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
| GitHub Pages for Flutter web | Switched from Netlify to GitHub Pages for simpler CI/CD integration via GitHub Actions |
| Google Sheets Service Account | Sheet is private and owned by the coach — service account (`crossfit-sheets@crossfit-app-496502.iam.gserviceaccount.com`) is the correct auth pattern for server-to-server access without OAuth |
| Configurable weight index for Sheets import | Refactored from hardcoded two-athlete (A/F) split to support N athletes with a per-athlete configurable weight column index — same program, different weights per athlete |
| `ALLOWED_ORIGINS` env var for CORS | Restricts API access to known frontend origins without hardcoding URLs; set to `https://ajenux.github.io` in Railway production |
| Configurable AI provider | Anthropic (Claude) used in production for better quality; Ollama used locally to avoid API costs during development — switched via environment variable |
| Split `ApiService` into feature-specific services | God class with mixed responsibilities made it hard to maintain and test; split into focused services per feature domain |
| Pre-push hook amends last commit | Amending instead of creating a new commit keeps PLAN.md updates atomic with the triggering commit, avoiding extra noise in git history |
| JWT refresh token (access 1h / refresh 7d) | Short-lived access tokens limit exposure if intercepted; refresh token allows seamless renewal without requiring re-login |
| `ApiClient.httpClient` injectable for tests | Static `http.Client` field replaceable with `MockClient` in tests — avoids DI framework overhead while enabling full HTTP-level test isolation for Flutter services |
| Bucket4j in-memory rate limiting | No Redis required for Railway deployment; `ConcurrentHashMap<IP, Bucket>` is sufficient for single-instance backend; `clearBuckets()` method enables test isolation |
