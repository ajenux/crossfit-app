# Changelog

## [Unreleased] - develop branch

### Phase 1 — Coach Availability Calendar
- Added `CoachAvailability` entity supporting two modes:
  - **Recurring** — e.g. every Monday 9am–12pm (`dayOfWeek` + `startTime` + `endTime`)
  - **Specific date** — e.g. December 5th 10am–2pm (`specificDate` + `startTime` + `endTime`)
- Added `CoachAvailabilityRepository`, `CoachAvailabilityService`, `CoachAvailabilityController`
- Endpoints at `/api/availability`:
  - `POST /api/availability` — coach creates an availability slot
  - `GET /api/availability/coach/{coachId}` — view all slots for a coach
  - `DELETE /api/availability/{id}` — coach removes a slot

### Phase 2 — Athlete Dashboard
- Added `AthleteDashboardResponse` DTO combining workouts + coach availability in one response
- Added `AthleteDashboardService` and `AthleteDashboardController`
- Endpoint: `GET /api/dashboard/athlete/{athleteId}`
  - Returns athlete info, assigned workouts, and their coach's availability slots
  - Athletes only see their own assigned coach's availability

### Phase 3 — AI Exercise Assistant with Media
- Added `POST /api/ai/exercise` endpoint
  - Accepts `{"exercise": "burpee"}`
  - Returns AI explanation (via Ollama/llama3.2) + GIF URL (via ExerciseDB)
- Added `explainExercise()` method to `AiService` with a focused prompt:
  - Muscles targeted
  - Step-by-step instructions
  - Common mistakes to avoid
- Added `ExerciseMediaService` using Spring `RestClient` to call ExerciseDB (RapidAPI)
  - GIF URL constructed from exercise `id`: `https://v2.exercisedb.io/image/{id}`
  - Media is optional — if ExerciseDB fails, explanation is still returned
- Added `exercisedb.api.key` property to `application.properties`

### AI — Workout Description Generator
- Added `POST /api/ai/generate-workout` endpoint
  - Accepts `{"name": "Monday Grind", "type": "AMRAP"}`
  - Returns AI-generated workout description under 100 words
- Added `generateWorkoutDescription()` method to `AiService`

### Fixes
- Fixed `AiController` class name corruption caused by IDE linter
- Fixed ExerciseDB GIF URL — new API version no longer returns `gifUrl` field directly; now constructed from `id`
- Fixed `application.properties` stray text on line 1
