# Project Plan — CrossFit App

Tracks what has been done, where we are, and what's next.
Updated whenever a phase is completed or started.

---

## Current status
**Active branch:** `develop`
**Last updated:** 2026-07-11 (session 10)
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
- [x] **In-app notifications** — bell icon with unread badge on athlete dashboard; `Notification` entity + `GET /api/notifications` + `PUT /api/notifications/read`; `WorkoutService.create()` fires notification on assignment; bulk Sheets import does not trigger per-workout notifications
- [x] **Athlete progress** — history of completed vs pending workouts; workout completion tracking
- [x] **Flutter: workout detail screen** — dedicated screen per workout with completion toggle; navigated from the workouts list
- [x] **Flutter: month tab selector, workout sections, warm theme** — athlete dashboard shows month tabs to filter workouts, workouts grouped into sections (including Estructura), warm color theme applied
- [x] **Auto-calculate import dates from month tab** — Sheets import start date derived automatically from the selected month tab; removed manual date entry from import flow
- [x] **Configurable training days** — coach selects Mon/Tue/Wed/Fri (or any days) per import; preference saved to DB (`ImportConfig`) and pre-selected on next open
- [x] **Weekly auto-import cron job** — runs daily at 6am; deduplicates via `lastImportedMonday`; retries automatically if Monday run fails; mirrors `_monthMap` from Flutter
- [x] **Bulk delete workouts by coach** — `DELETE /api/workouts/coach/{coachId}` + "Clear all" button in Import tab with confirmation dialog
- [x] **WOD section detection** — fixed two bugs: (1) sheet parser now reads both even and odd columns per day so WOD content in adjacent column is captured; (2) ladder-style WODs (`15-12-9-6-3`) now detected as `[WOD]` section header
- [x] **Tab disambiguation** — when multiple sheet tabs match the same month (e.g. "Mayo" old + "maio" current), the last matching tab is preferred; fixes importing stale data from duplicate tabs
- [x] **Robust auto-import pipeline** (session 8) — complete redesign with three pillars:
  - *Idempotency*: `sheetsSourceKey` field on `Workout` (e.g. `"2026-06-16-D1"`); import does upsert — re-running never creates duplicates or overwrites `completed` state
  - *Dual trigger*: scheduler now runs 4×/day (6am/10am/2pm/6pm) AND `AthleteDashboardController` triggers import synchronously on first load of the week if athlete has no sheet workouts yet
  - *Visibility*: `ImportConfig` gains `lastAttemptAt`, `lastSuccessAt`, `lastError`; exposed via `GET /api/import-config/{coachId}`
  - *Centralised logic*: new `AutoImportService` is the single orchestrator; both scheduler and dashboard call the same code path
  - *Robust tab matching*: changed from exact key lookup to `startsWith` — tab names like `"Junio 2026"` now resolve correctly
- [x] **Sheets week alignment fix** (session 9) — parse and expose the sheet's own "Semana N" label per week/workout instead of assuming week N lines up with the N-th calendar week of the month; fixes both the import logic and the Import tab "Start date" field, which relied on the same broken assumption
- [x] **Auto-backfill import** (session 9) — replaced calendar-guessed week numbers with an anchor + 7-day-offset model: once one week's real date is confirmed (manually or automatically), every other week in that sheet tab backfills automatically (past and present, up to today) instead of requiring a manual click per week; guards against the anchor moving backwards from a historical cleanup import, and against the scheduler re-advancing past the current week on repeated same-day runs
- [x] **Workout naming cleanup** (session 9) — "Dia N" replaces the redundant/stale "S{weekNumber}-D{n} {athlete name}" naming, refreshed on re-import
- [x] **Flutter: redesigned athlete workout view** (session 9) — paginate by month with prev/next navigation; workouts grouped into collapsible per-week sections labeled with the coach's own "Semana N" instead of one long flat list
- [x] **AI results surfaced in coach dashboard** (session 10) — "Generate with AI" button in the Create Workout dialog calls the previously-unused `POST /api/ai/generate-workout` endpoint and fills the description field automatically, based on the workout name/type; tested end-to-end locally (Postgres + Ollama)
- [x] **"Esta semana: X RxC" badge** — `_RxCCard` on the athlete dashboard and `_RxCBadge` on the workout detail screen extract the `\d+\s*RxC` pattern from the nearest-date workout description and surface it prominently; already implemented (commit `5b504fa`), PLAN.md just hadn't been updated to reflect it
- [x] **Password reset (email-based)** (session 10) — full forgot/reset password flow:
  - Backend: `PasswordResetToken` entity (single-use, 30 min expiry) + `PasswordResetService` + `EmailService` (Spring Mail, Gmail SMTP); `POST /api/auth/forgot-password` and `POST /api/auth/reset-password`; always returns 200 on forgot-password regardless of whether the email exists, to avoid leaking registered addresses; resetting a password deletes all of that user's refresh tokens, forcing re-login everywhere
  - Rate limiting extended to `/api/auth/forgot-password` (same 5/min/IP bucket as login) to prevent email-bombing abuse
  - Flutter: `ForgotPasswordScreen` and `ResetPasswordScreen` (`/forgot-password`, `/reset-password?token=`), "Forgot password?" link on login
  - Tested end-to-end locally against real Postgres: token creation, reset, old password rejected, new password accepted, token single-use enforced — all verified via API and through the Flutter web UI
  - **Requires setup before it works in production**: Railway needs `MAIL_USERNAME`, `MAIL_PASSWORD` (Gmail App Password), and optionally `MAIL_FROM`/`FRONTEND_URL` env vars — not yet configured there
- [x] **Email verification on registration** (session 10) — new accounts can't log in until they click the link sent to their email:
  - Backend: `EmailVerificationToken` entity (single-use, 24h expiry) + `EmailVerificationService`; `User.emailVerified` defaults to `false` in Java for new registrations but `true` at the DB level so existing rows aren't locked out by the migration; `register()` sends the verification email, `login()` throws `EmailNotVerifiedException` (403) if unverified; `POST /api/auth/verify-email` and `POST /api/auth/resend-verification` (the latter always returns 200 regardless of whether the email exists or is already verified, same anti-enumeration pattern as forgot-password)
  - Flutter: `VerifyEmailScreen` (`/verify-email?token=`) handles the email link; `RegisterScreen` shows a "check your email" confirmation instead of navigating away; `LoginScreen` surfaces the 403 detail message and offers a "Resend verification email" button
  - Demo seed accounts (`DataInitializer`) explicitly marked `emailVerified=true` so they keep working without a real inbox
  - Reuses the `EmailService`/token infrastructure built for password reset

### Quality
- [x] 31 automated tests (16 service unit tests + 15 controller integration tests) — 15 added in session 10 for password reset and email verification (`AuthServiceTest`, `AuthControllerTest`)
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
- [x] Fix `completed` column migration — add `DEFAULT false` for existing rows
- [x] Fix workout detail — type label, date format, and section fallback
- [x] **Local dev environment parity** (session 8) — local and production now run identically:
  - `docker-compose.yml` for one-command Postgres setup (machines with Docker)
  - Homebrew Postgres supported out of the box (machines without Docker)
  - `start-local.sh` — robust startup script that loads vars line-by-line from `.env` and reads `GOOGLE_CREDENTIALS_JSON` from `.google-credentials.json` (avoids shell escaping issues with the service account private key)
  - `.env.example` updated with all required vars and inline comments
  - Both environments use `SPRING_PROFILES_ACTIVE=demo`
  - Tested end-to-end locally: login, auto-import from sheet, idempotency verified
- [x] **CORS fix for local Flutter web** (session 8) — switched from `setAllowedOrigins` to `setAllowedOriginPatterns` so `http://localhost:*` wildcard works; Flutter web picks a random port on every run so hardcoding was not viable
- [x] **Fix Flutter web local dev API URL** (session 9) — web build now defaults `API_URL` to localhost instead of the Android emulator address (`10.0.2.2`), which previously hung silently on web with no error
- [x] **`DEPLOY.md` rewritten** (session 10) — the old version still described a pending Netlify setup even though production has used GitHub Pages for several sessions (`railway.toml` was also referenced but never existed); replaced with the actual current setup (Railway auto-deploy via GitHub integration, GitHub Pages workflow) and a complete table of required Railway env vars, including the new `MAIL_*`/`FRONTEND_URL` vars for password reset

---

## Pending / Next steps

### Setup needed
- [ ] **Configure Gmail SMTP in Railway** — add `MAIL_USERNAME` and `MAIL_PASSWORD` (Gmail App Password: https://myaccount.google.com/apppasswords) to Railway production env vars so password reset **and** email verification emails actually send; code is done and tested, just needs credentials. Without this, new registrations in production will be locked out of login (no verification email arrives, no way to confirm the account)

### Maturity gaps (from session 10 self-review)
- [ ] **Broader rate limiting** — Bucket4j currently only guards `/api/auth/login` and `/api/auth/forgot-password`; registration and other sensitive write endpoints are unprotected
- [ ] **Unit tests for the Google Sheets parser** — `GoogleSheetsService` (week alignment, section markers, WOD detection) is the most complex and historically buggiest logic in the app, but has no dedicated unit tests — only covered indirectly through manual end-to-end verification each session
- [ ] **Observability** — no structured logging, metrics, or alerting; production issues are currently discovered via user reports, not a dashboard. Deliberately left for last (per user, 2026-07-11)

### Low priority / Future ideas
- [ ] **Better AI models** — evaluate more capable models for AI features (currently `claude-haiku-4-5-20251001` in production, `llama3.2` via Ollama locally)

---

## Key technical decisions

| Decision | Reason |
|----------|--------|
| `@OneToOne` between `User` and `Athlete`/`Coach` | Email-only relationship was fragile; FK enforces referential integrity |
| `GlobalExceptionHandler` for 403 | Spring Security 7 does not propagate service-layer `AccessDeniedException` through `ExceptionTranslationFilter` correctly |
| `@Transactional(readOnly=true)` on `AthleteDashboardService` | Without a transaction, `WorkoutResponse` constructor cannot access lazy-loaded `Athlete` and `Coach` associations |
| `SecurityMockMvcRequestPostProcessors.user()` in tests | `@WithMockUser` does not work with Spring Boot 4's new `@AutoConfigureMockMvc` |
| Environment variables for credentials | `.env` + `.env.example` pattern, `.env` in `.gitignore` |
| Railway for backend deployment | Chosen for zero-config PostgreSQL add-on and auto-detected Maven/Spring Boot builds — no config file needed, deploys via Railway's GitHub integration on push to `master` |
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
| Auto-calculate import dates from month tab | Deriving the start date from the selected month tab removes a manual input step and reduces import errors; month tab already encodes the correct calendar context |
| `AutoImportService` as central orchestrator | Eliminates duplicated import logic between scheduler and dashboard trigger; single code path means fixes and improvements apply everywhere automatically |
| `sheetsSourceKey` for idempotent import | Storing the sheet origin key on each workout makes re-running imports safe and enables the dual-trigger pattern without risk of duplicates |
| Dashboard-triggered import (synchronous) | Guarantees data freshness on first load of the week even if all scheduler runs failed; latency (~1-2s) acceptable since it only fires once per week per athlete |
| `start-local.sh` for local dev | `export $(cat .env | xargs)` breaks on Google service account JSON (special chars, multiline private key); reading credentials from a separate file is the only reliable approach |
| `.google-credentials.json` separate from `.env` | Keeps the service account JSON out of shell variable parsing entirely; gitignored, same credentials file works for both Sheets and any future Google API |
| `setAllowedOriginPatterns` for CORS | `setAllowedOrigins` does not support wildcards; Flutter web uses a random port on every run so `http://localhost:*` pattern is the only viable local dev approach |
| Anchor + 7-day-offset model for week alignment | Calendar-week guessing silently imported the wrong week; using the sheet's own "Semana N" label plus a confirmed anchor date lets every other week be derived and backfilled reliably |
| Gmail SMTP for password reset emails | Simplest option with no extra billing account for a personal project; Spring Boot's `spring-boot-starter-mail` needs only host/username/app-password, no SDK integration like SendGrid/SES |
| Password reset always returns 200 | Returning the same response whether or not the email exists prevents attackers from using the endpoint to enumerate registered accounts |
| Reset invalidates all refresh tokens | If a password was reset (e.g. after a suspected compromise), every existing session should be forced to log in again with the new password |
| Hash-based routing (`/#/reset-password?token=`) for the email link | Flutter web's default `go_router` URL strategy is hash-based, which works out of the box on GitHub Pages static hosting with no server-side rewrite rules needed |
| `emailVerified` defaults `true` at the DB level, `false` in Java | New column added to an existing table — a DB-level default of `true` backfills existing rows as verified so nobody already registered gets locked out, while the Java-side default of `false` still applies to every new registration going forward |
| Resend-verification always returns 200 | Same anti-enumeration reasoning as forgot-password — the response must not reveal whether the email is registered or already verified |
