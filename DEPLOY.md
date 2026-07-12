# Deploy Instructions

## Current setup

- **Backend**: Railway (`https://crossfit-app-production-fcf2.up.railway.app`), auto-deploys on push to `master` via Railway's GitHub integration (no `railway.toml` — Railway auto-detects the Maven/Spring Boot project). Postgres is a Railway plugin; its `PGHOST`/`PGPORT`/`PGDATABASE`/`PGUSER`/`PGPASSWORD` variables are auto-injected and match what `application-demo.properties` expects.
- **Frontend**: GitHub Pages (`https://ajenux.github.io/crossfit-app`), built and deployed by `.github/workflows/deploy-web.yml` on every push to `master`.
- Both run with `SPRING_PROFILES_ACTIVE=demo`, same as local dev (see `CLAUDE.md`).

## Frontend deploy (GitHub Pages)

Handled entirely by `.github/workflows/deploy-web.yml`:
1. Builds `mobile/` with `flutter build web --release --base-href=/crossfit-app/`
2. Injects `API_URL` from the **GitHub repo variable** (Settings → Secrets and variables → Actions → **Variables** tab, not Secrets) pointing at the Railway backend URL
3. Deploys the build output to GitHub Pages

No manual steps needed — push to `master` (or run the workflow manually via `workflow_dispatch`) and it deploys.

## Backend deploy (Railway)

Push to `master` triggers a Railway deploy automatically (GitHub integration configured on the Railway project). No local `railway up` or CLI steps needed for routine deploys.

### Required environment variables (Railway project settings)

| Variable | Purpose | Notes |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | Activates `application-demo.properties` | Set to `demo` |
| `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD` | Postgres connection | Auto-injected by the Railway Postgres plugin — reference them, don't hardcode |
| `JWT_SECRET` | Signs access/refresh tokens | ≥256 bits |
| `CORS_ALLOWED_ORIGINS` | Restricts API access | Set to `https://ajenux.github.io` |
| `GOOGLE_CREDENTIALS_JSON` | Sheets service account | Full JSON on one line |
| `GOOGLE_SHEETS_SPREADSHEET_ID` | Coach's training sheet | Defaults to the current sheet if unset |
| `ANTHROPIC_API_KEY` | AI provider in production | Falls back to Ollama if unset (not usable on Railway — no local Ollama there) |
| `EXERCISEDB_API_KEY` | Exercise GIFs (RapidAPI) | Used by the exercise assistant |
| `MAIL_USERNAME`, `MAIL_PASSWORD` | Gmail SMTP for password reset emails | `MAIL_PASSWORD` is a Gmail **App Password**, not the account password: https://myaccount.google.com/apppasswords — **not yet configured**, password reset emails won't send until these are set |
| `MAIL_FROM` | "From" address on reset emails | Optional — defaults to `MAIL_USERNAME` |
| `FRONTEND_URL` | Base URL embedded in the reset link | Optional — defaults to the GitHub Pages URL above |

`PORT` is injected by Railway automatically and does not need to be set manually.

## Demo accounts (created by `DataInitializer`)

| Email | Password | Role |
|---|---|---|
| `coach@demo.com` | `Demo1234` | COACH |
| `athlete1@demo.com` | `Demo1234` | ATHLETE |
| `athlete2@demo.com` | `Demo1234` | ATHLETE |