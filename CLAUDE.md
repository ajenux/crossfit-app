# CrossFit App — Claude Instructions

## What this project is

A single-screen web app that shows my current training week from my coach's
Google Sheet. Live at `https://ajenux.github.io/crossfit-app`. No login, no
backend, no paid hosting. That is the whole goal — do not expand it.

Read `README.md` first; it describes exactly what is deployed and how.

## What matters

- `tools/sheet_to_json.py` — reads the sheet, writes `workouts.json`
- `mobile/lib/main.dart` + `mobile/lib/week/week_app.dart` — the viewer
- `.github/workflows/deploy-web.yml` — builds and deploys to GitHub Pages
  (push to `master`, daily cron 05:00 UTC, or manual)

## Start of every session

1. Read `README.md`.
2. Run `git log --oneline -5`.
3. Ask the user what they want. Don't propose new features.

## Rules

- Work on `develop`; merge to `master` only when the change is verified
  (build passes, page checked in the browser). Pushing to `master` deploys.
- Never stage, commit or push without asking the user first.
- Verify against the real sheet (`.google-credentials.json` is local and
  gitignored) before claiming something works. Don't assume tab names or
  dates — check them.
- If something in the sheet is skipped or ignored, say so; never drop data
  silently.
- Code comments, commit messages and docs in English. Talk to the user in
  the language they use.
- Keep changes small. One screen, one script, one workflow.

## Local run

See "Run locally" in `README.md`.
