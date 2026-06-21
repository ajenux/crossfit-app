# CrossFit App — Claude Instructions

## Start of every session

1. Read `PLAN.md` — it is the source of truth for what is done and what is pending.
2. Run `git log --oneline -5` to see the latest commits.
3. Ask the user where they want to pick up.

## Project summary

Spring Boot 4 REST API + Flutter mobile app for managing CrossFit coaches, athletes, and workouts.

- Backend: Java 21, Spring Security + JWT, Spring Data JPA, PostgreSQL
- Frontend: Flutter (go_router, SharedPreferences, http)
- AI: Ollama (exercise assistant + workout generator)
- Auth: stateless JWT, roles COACH / ATHLETE

Key files:
- `src/main/java/com/example/demo/` — backend source
- `mobile/lib/` — Flutter source
- `PLAN.md` — task tracker (done / pending / key decisions)
- `CHANGELOG.md` — feature history by phase
- `ARCHITECTURE.md` — full system documentation

## Local development

Both local and production run with `SPRING_PROFILES_ACTIVE=demo` so behaviour is identical.

**First-time setup:**
```bash
cp .env.example .env          # fill in JWT_SECRET and GOOGLE_CREDENTIALS_JSON
docker-compose up -d          # start Postgres (port 5432)
```

**Run the backend:**
```bash
export $(cat .env | xargs)
./mvnw spring-boot:run -Dspring-boot.run.profiles=demo
```

**Run the Flutter app:**
```bash
cd mobile && flutter run
```

**Stop Postgres:**
```bash
docker-compose down
```

Demo accounts seeded automatically on first start:
- `coach@demo.com` / `Demo1234`
- `athlete1@demo.com` / `Demo1234`
- `athlete2@demo.com` / `Demo1234`

## Rules

- Always work on `develop`. Merge to `master` only when confirmed working.
- Write all code comments, commit messages, PR descriptions, and docs in English.
- Never stage or commit without asking the user first.
- Before pushing to develop, run `./scripts/update-plan.sh` to keep PLAN.md current.
- The `prepare-commit-msg` hook generates AI-assisted commit messages automatically.
