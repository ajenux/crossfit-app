# Mi semana — CrossFit training viewer

A single-screen web app that shows the current training week from our coach's
Google Sheet, so Ale and Fabita don't have to open the sheet itself.

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
