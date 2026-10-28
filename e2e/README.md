# End-to-end check

The functional tests of the app (see `TESTING.md` at the repo root). They
lived in the private repo `ajenux/crossfit-app-e2e` until 2026-10-28.

`app.spec.mjs` (Playwright, uses the Chrome installed on the machine)
checks everything the week viewer promises against the real thing — the published page, its
`workouts.json`, the Apps Script and the coach's sheet:

- `workouts.json` is fresh (< 26 h), well formed, has no empty Fuerza
  block, and matches what the parser reads from the sheet right now (day
  contents that changed since the last build are reported, not failed);
- first-visit prompt, opening on today's week with its dates, ◀ ▶, every
  day of this week rendered as in the sheet for Ale / Fabita / Ambos,
  weight chips, "done" checkbox persistence;
- the Apps Script rejects bad input (wrong PIN, bad day, unknown person);
- notes: Ale and Fabita on separate "devices", exercise rows reduced to
  their names, who may edit what, stored in the datos `Notas` tab, deleting a
  note;
- coach: wrong PIN refused, PIN accepted, a day edited from the page is
  logged in `Ediciones` with its base, shows on another device, and gives way
  to the sheet's version once that day changes there;
- **the coach's sheet did not change by a single cell** during the run.

Writes go only to "Mi semana — datos", under a made-up `E2E` month that the
page never shows on its own (the test injec## Setup

It reuses the repo root's parser, virtualenv and service-account key.

```bash
# at the repo root: venv + key (see the root README, "Run locally")
python3 -m venv .venv && .venv/bin/pip install google-auth requests
# copy .google-credentials.json there (not in git; keep it in your password manager)

cd e2e
npm install
cp .env.example .env   # then set COACH_PIN with an editor
```

Needs Google Chrome installed (Playwright drives it; no browser download).

 download).
If the app checkout is elsewhere, set `APP_DIR`.

## Run

```bash
npx playwright test                                   # against the published page
BASE_URL=http://localhost:8765/ npx playwright test   # against a local build
npx playwright test -g "viewer"                       # just one group
```

Without `COACH_PIN` the notes/coach part is skipped.
