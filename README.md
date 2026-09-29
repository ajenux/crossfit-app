# Mi semana — CrossFit training viewer

A single-screen web app that shows the current training week from our coach's
Google Sheet, so Ale and Fabita don't have to open the sheet itself.

**Live:** https://ajenux.github.io/crossfit-app

No login, no server of our own, no paid hosting. The whole thing is a static
page on GitHub Pages plus a scheduled GitHub Action, and one Google Apps
Script for the few things a static page can't do (weight notes and coach
edits).

**The coach's sheet is never written to.** It is only read, by the daily
build, with a read-only service account. Everything the page saves goes to
a separate spreadsheet of ours, "Mi semana — datos".

## How it works

```
GitHub Action (push to master · daily 05:00 UTC · manual)
   ├─ tools/sheet_to_json.py  reads the sheet with a service account
   │                          and writes workouts.json
   └─ flutter build web       builds mobile/lib/main.dart
                              and publishes both to GitHub Pages

Browser
   ├─ loads workouts.json and shows the current week
   └─ apps_script/Code.gs  web app bound to "Mi semana — datos" (optional)
        GET  notes + coach edits
        POST a weight note, or a coach edit of a day
```

### What the page does

- **First visit** asks "¿Quién eres?" (Ale / Fabita Rumana Portillo) and
  remembers the answer in that browser, so the same URL works for both.
- Opens on **the week that contains today**. Each week shows its dates
  ("Semana 4 · 21 – 27 sep"): the sheet has none, so "Semana 1" is taken as
  the week holding the 1st of the month and each next week is 7 days later.
  If today's week isn't written yet, it falls back to the last week of this
  month's tab, then to the newest week in the sheet.
- The coach names tabs freely (`Sep`, `Sept`, `Septi`, `Agos`…); any prefix
  of a Spanish month name works, and it is shown as "Septiembre 2026" — the
  year is inferred from tab order since titles don't carry it.
- One card per day (`Dia 1`, `Dia 2`…), split into **Estructura / Fuerza / WOD**
  by the same heuristics as the sheet layout, with the `N RxC` badge.
- ◀ ▶ to browse previous weeks.
- **Pesos** chips: the sheet writes weights as `(X/Y)`; **Ale** gets the
  heavier of each pair, **Fabita** the lighter (by value, not position), and
  **Ambos** shows the pair as written. Changing it updates the saved choice.
- A checkbox per day to mark it done. Also stored in the browser only.
- Always fetches fresh data (cache-busting query, no service worker).
- **Pesos logrados** under each day: Ale and Fabita each note what they
  reached. Everyone sees both notes on any device; you can edit your own
  line (the one matching the Pesos chip). The editor lists the day's
  exercises as ready-made rows, so only the value is typed: every Fuerza
  line, Estructura lines that ramp up ("subiendo", "heavy"), and one
  `WOD · …` row for rounds/score. Each row shows just the exercise's name
  ("5x2 deadlift (125/95) foco velocidad" → "Deadlift"; see
  `_exerciseName`, whose rules were checked against every Fuerza line in the
  sheet). "Otro ejercicio" adds a free row; empty rows aren't saved.
  Stored in the datos `Notas` tab as plain text, one `exercise: value` line
  each (e.g. `Deadlift: 130`).
- **Entrenador**: third option in "¿Quién eres?" (or "Soy el entrenador"),
  asks for a PIN. The coach can edit any day (Estructura / Fuerza / WOD) and
  both people's notes. An edit is saved in the datos `Ediciones` tab together
  with the day as it was (`Base`), and the page shows it on top of the
  sheet on every device. **His own sheet does not change.** If he later
  changes that day in his sheet, the day no longer matches the edit's base
  and his sheet's version is shown again, so an old edit never hides a newer
  change. The PIN is remembered in that browser.

Notes and coach edits only appear when the page was built with an Apps
Script URL (see below); without it the page behaves as a plain viewer.

### Sheet format expected

One tab per month. Inside a tab, a week starts at a row whose column A is
`Dia 1`, optionally preceded by a `Semana N` label row. Each day takes two
columns (main block + WOD block). See `tools/sheet_to_json.py` for the exact
rules.

## Notes and coach edits (Apps Script)

`apps_script/Code.gs` runs as a Google Apps Script web app bound to our own
spreadsheet ["Mi semana — datos"](https://docs.google.com/spreadsheets/d/16tadRfWZ1V1MMW9OBFo-ydMz-IP2BXivwr16hYsJuGo/edit)
(owned by ajenux@gmail.com). It is marked `@OnlyCurrentDoc`, so Google only
lets it open that spreadsheet — it can't reach the coach's sheet even by
mistake.

1. Open "Mi semana — datos" → Extensions → Apps Script. Replace `Code.gs`
   with `apps_script/Code.gs` from this repo and save.
   **Start from "Mi semana — datos", never from the coach's sheet**: the
   Apps Script editor looks identical either way, but a project opened from
   the coach's sheet would write into it. Check the project name in the
   editor ("Mi semana — datos (script)") before deploying, and after
   deploying check that a test note lands in "Mi semana — datos".
2. Project Settings → Script properties → add `COACH_PIN` = the coach's PIN.
3. Deploy → New deployment → type **Web app**, Execute as **Me**, Who has
   access **Anyone**. Authorize, and copy the web app URL (`.../exec`).
4. Tell the build about it and redeploy:
   ```
   gh variable set APPS_SCRIPT_URL --body "https://script.google.com/macros/s/.../exec"
   gh workflow run deploy-web.yml --ref master
   ```

After changing `Code.gs`, use Deploy → Manage deployments → edit → New
version, so the URL stays the same.

What to know:
- The script creates the `Notas` and `Ediciones` tabs on first use.
- Emptying a note deletes its row; edits are only appended (history).
- Notes need no PIN: anyone with the link can write them. Day edits need
  the PIN.

## Repository layout

| Path | What |
|---|---|
| `tools/sheet_to_json.py` | Sheet → `workouts.json` (Python, Google Sheets API v4) |
| `mobile/lib/main.dart`, `mobile/lib/week/` | The viewer (Flutter web) |
| `apps_script/Code.gs` | Notes + coach edits (Google Apps Script, bound to "Mi semana — datos") |
| `.github/workflows/deploy-web.yml` | Build + deploy to GitHub Pages |

## Setup

One secret is needed in the GitHub repo (plus the optional `APPS_SCRIPT_URL`
variable described above):

```
gh secret set GOOGLE_CREDENTIALS_JSON < .google-credentials.json
```

That is the Google service account JSON that has read access to the sheet.
The spreadsheet ID defaults to the coach's sheet; override with the
`GOOGLE_SHEETS_SPREADSHEET_ID` env var in the workflow if it changes.

## Run locally

```bash
# 1. Generate the JSON from the real sheet
python3 -m venv .venv && .venv/bin/pip install google-auth requests
.venv/bin/python tools/sheet_to_json.py --credentials .google-credentials.json workouts.json

# 2. Build the viewer and serve it
cd mobile
flutter build web --release --pwa-strategy=none --base-href=/
# add --dart-define=APPS_SCRIPT_URL=https://script.google.com/macros/s/.../exec
# to enable notes and coach edits
cp ../workouts.json build/web/
python3 -m http.server 8765 --directory build/web
# open http://localhost:8765
```

## Deploy

Push to `master`, or trigger manually:

```bash
gh workflow run deploy-web.yml --ref master
```

The cron run every morning picks up whatever the coach added to the sheet.

## Branching

- `develop` — work here
- `master` — what is deployed
