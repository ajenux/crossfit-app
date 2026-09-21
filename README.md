# Mi semana — CrossFit training viewer

A single-screen web app that shows my current training week from my coach's
Google Sheet, so I don't have to open the sheet itself.

**Live:** https://ajenux.github.io/crossfit-app

No login, no backend, no paid hosting. The whole thing is a static page on
GitHub Pages plus a scheduled GitHub Action.

## How it works

```
GitHub Action (push to master · daily 05:00 UTC · manual)
   ├─ tools/sheet_to_json.py  reads the sheet with a service account
   │                          and writes workouts.json
   └─ flutter build web       builds mobile/lib/main.dart
                              and publishes both to GitHub Pages

Browser
   └─ loads workouts.json and shows the current week
```

### What the page does

- Opens on the **last tab for the current calendar month**, last week in it.
  The coach names tabs freely (`Sep`, `Sept`, `Septi`, `Agos`…); any prefix
  of a Spanish month name works. If the month has no tab yet, it shows the
  newest week in the sheet.
- One card per day (`Dia 1`, `Dia 2`…), split into **Estructura / Fuerza / WOD**
  by the same heuristics as the sheet layout, with the `N RxC` badge.
- ◀ ▶ to browse previous weeks.
- **Pesos** selector: the sheet writes weights as `(X/Y)` for two athletes;
  pick `1º` or `2º` to see only yours. Remembered in the browser.
- A checkbox per day to mark it done. Also stored in the browser only.
- Always fetches fresh data (cache-busting query, no service worker).

### Sheet format expected

One tab per month. Inside a tab, a week starts at a row whose column A is
`Dia 1`, optionally preceded by a `Semana N` label row. Each day takes two
columns (main block + WOD block). See `tools/sheet_to_json.py` for the exact
rules.

## Repository layout

| Path | What |
|---|---|
| `tools/sheet_to_json.py` | Sheet → `workouts.json` (Python, Google Sheets API v4) |
| `mobile/lib/main.dart`, `mobile/lib/week/` | The viewer (Flutter web) |
| `.github/workflows/deploy-web.yml` | Build + deploy to GitHub Pages |

## Setup

Only one secret is needed in the GitHub repo:

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
