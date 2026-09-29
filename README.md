# crossfit-app-e2e

Private end-to-end check for [crossfit-app](https://github.com/ajenux/crossfit-app).

`app.spec.mjs` (Playwright, uses the Chrome installed on the machine)
checks everything crossfit-app promises against the real thing — the published page, its
`workouts.json`, the Apps Script and the sheet:

- `workouts.json` is fresh (< 26 h), well formed, has no empty Fuerza
  block, and matches what the parser reads from the sheet right now (day
  contents that changed since the last build are reported, not failed);
- first-visit prompt, opening on today's week with its dates, ◀ ▶, every
  day of this week rendered as in the sheet for Ale / Fabita / Ambos,
  weight chips, "done" checkbox persistence;
- the Apps Script rejects bad input (wrong PIN, unknown week/person);
- notes: Ale and Fabita on separate "devices", ready-made exercise rows,
  who may edit what, the text stored in `Notas`, deleting a note;
- coach: wrong PIN refused, PIN accepted, a day edited from the page lands
  in the sheet cells (rows inserted, the rest of the week and the next week
  untouched), reads back identically through `sheet_to_json.py`, is logged
  in `Ediciones` and shows on another device before any rebuild.

It writes only to a sandbox tab **`E2E`** in the sheet (the page never shows
it on its own; the test injects it into `workouts.json`), and resets it at
the end. Month tabs are only read.

## Setup on a new machine

This repo is private on purpose; it lives next to the public app repo and
reuses its parser, virtualenv and service-account key.

```bash
mkdir -p ~/Projects && cd ~/Projects
git clone https://github.com/ajenux/crossfit-app.git
git clone https://github.com/ajenux/crossfit-app-e2e.git

# crossfit-app: venv + key (see its README "Run locally")
cd crossfit-app
python3 -m venv .venv && .venv/bin/pip install google-auth requests
# copy .google-credentials.json here (not in git; keep it in your password manager)

# this repo
cd ../crossfit-app-e2e
npm install
cp .env.example .env   # then set COACH_PIN with an editor
```

Needs Google Chrome installed (Playwright drives it; no browser download).
If the app checkout is elsewhere, set `APP_DIR`.

One-time, in the sheet: a tab named `E2E` with this pasted at `A1`
(tab-separated; once per sheet, not per machine):

```
Semana 1
Dia 1		Dia 2
4 RxC		3 RxC
base estructura		otro dia estructura
Fuerza		Fuerza
5x3 back squat (100/70)		5x1 push press (60/40)
amrap 10		emom 10
10 burpees		5 pullups
Semana 2
Dia 1
2 RxC
semana dos no tocar
```

## Run

```bash
npx playwright test                                   # against the published page
BASE_URL=http://localhost:8765/ npx playwright test   # against a local build
npx playwright test -g "viewer"                       # just one group
```

Without `COACH_PIN` the notes/coach part is skipped.

Without `COACH_PIN` the notes/coach part is skipped. Each coach edit that is
longer than the block inserts rows in the `E2E` tab; they stay empty.
