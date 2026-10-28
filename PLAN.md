# Status and plan

Where the project stands, what's decided, and in what order to keep going.
Updated whenever something changes state, in the same pull request; the
README explains _how_ what is deployed works, this file explains _where it's
heading_. It is the north: what isn't here doesn't get built.

**Live:** https://ajenux.github.io/crossfit-app (the week viewer, phase 0)
**Last updated:** 2026-10-28

---

## Current status

**The week viewer is live and stays live** until the redefined app replaces
it: Ale and Fabi see their week from the coach's sheet, note weights, and the
coach can edit a day with a PIN. See phase 0.

**The project got redefined on 2026-10-28.** It is no longer a viewer for
two people: it is an app for a coach and his athletes, where the athlete
sees today's plan split into phases, looks up how each exercise is done, and
leaves notes the coach reads and answers. The decisions taken so far are in
"Decisions made"; what's still open is in "What's still undecided".

**Nothing of the redefined app is built yet.** The process rules (tests per
layer, branch per change, this plan as the north) were set up first, copied
from the FL1 project and adapted.

| Check                      | Status                                          |
| -------------------------- | ----------------------------------------------- |
| `flutter analyze`          | No issues                                       |
| Unit tests                 | 0 — none exist in this repo yet                 |
| Integration tests          | 0                                               |
| Functional tests           | 16, in `e2e/`, covering the viewer; they run on every pull request |

---

## What comes next, in order

1. **Decide the first version's scope** — what it does and for whom, and
   what happens with the current viewer and `~/crossfit_flutter`. Open
   question 1 below; it blocks the rest.
2. **Process pieces that need the user's approval** (see "Debt and risks"):
   branch protection on `master`, retiring `develop`, the `check` workflow's
   first run.
3. **Design the core model** — athletes, coaches, plans, phases, exercises,
   notes, coach replies — as domain types with pure rules and their tests.
4. **The sheet adapter** — reads the shared plan sheet into the core model,
   writes athlete notes back, reads the coach's replies. Against a fixture
   copy of the sheet's real layout.
5. Then, in an order to be set once 1 is decided: Supabase (auth, roles,
   data), the athlete's screens, the coach's screens, the exercise catalog.

---

## Facts verified about the coach's flow (2026-10-28)

Checked in the shared plan sheet and in the coach's own app ("Dotta Crew",
an Apps Script web app with one link per athlete).

- **Dotta Crew reads this same plan sheet** and personalizes it per
  athlete: `(135/103)` becomes `(135)` for Ale, `12/9 cal ab` becomes
  `12 cal ab`, and another athlete's inline note (`6 pu (Fabi: ring rows si
  molesta)`) is hidden.
- **Phases are the blocks of a day, named by their first line**: `N RxC`
  (structure), a literal `Fuerza` row, and the WOD's format (`amrap 14`,
  `EMOM X24`, `21-15-9 reps`, `5x AMRAP 3' REST 1'`). Only `Fuerza` is an
  explicit label. Weeks carry tags (`Semana 2 - DESCARGA`), and free rows
  appear (`sin romper series`).
- **The coach's adaptations already live inline in the plan text**, per
  athlete or for everyone: `(Fabi: ring rows si molesta)`, `(o pike push
  ups)`, `(si rompe, 6-8 y suma)`.
- **Athlete notes are not in the plan sheet**: no cell notes, no links, no
  note columns (each day's second column is empty). Dotta Crew stores them
  elsewhere.
- **What Dotta Crew lets an athlete note**: per exercise and per WOD — what
  was done (kg × reps), feeling (Fácil / Bien / Duro / Muy duro), pain 0–10,
  a note; a "Cierre del día" with feeling, pain and note.
- **Its "Video" button opens a public YouTube video** in a new tab, matched
  by name; one checked was wrong (`kip swing + kipping pullup` → "Russian
  Kettlebell Swing").

---

## Decisions made

| Topic | Decision | Why | Ruled out |
| --- | --- | --- | --- |
| Source of the plans | The coach's Google Sheet, for now | It's how he works and he's comfortable with it; he'd move only to something simpler that adds value | Asking him to change tools first |
| Architecture | A clean core model plus adapters at the edges; the sheet's layout is not the data model | When the coach leaves the sheet, only the adapter changes | Mirroring the sheet's layout in the app |
| Athlete notes | They end up in the coach's sheet, where he reads them before writing the next week | He has to see them without changing how he works | Keeping them only in our own store |
| Writing to the shared plan sheet | Allowed: the coach granted read and write and keeps a backup | Needed for the notes to reach him | — (this reverses the viewer's "never write to the coach's sheet") |
| Coach replies | Both specific (one athlete, one exercise, one day) and standing ("no kipping until further notice"); a reply can either replace the exercise in the plan or only advise. While on the sheet, he writes them in the sheet | It's what he already does inline | — |
| Phases | Not fixed: the app takes the blocks each day comes with | Ale and Fabi have structure / strength / WOD; olympic-lifting clients have other shapes | Hard-coding three phases |
| Roles | Athlete or coach, never both; one coach for now | — | — |
| Many coaches | Designed for later: each coach with his own name and logo | Other coaches may use it | Building multi-coach now |
| Access | Sign in once and stay signed in, with Google or with a username and password the phone can save | An exercise app, not a bank: the worst leak is someone seeing another's plan | Per-athlete secret links (forwardable); anything heavier |
| Backend | Supabase free plan: auth, Postgres, row-level permissions per role, small functions for the sheet. Nightly database backup from GitHub Actions | US$0; login and roles come solved. 4 coaches × 20 athletes stays far under the free limits (500 MB, 50 000 monthly users, 5 GB traffic, per third-party sources — confirm at supabase.com/pricing before building) | Railway (≈ US$5/month; FL1's account belongs to the workshop), Firebase (writing to the sheet needs the paid plan), Apps Script (slow, a sheet as database) |
| Keeping the backend replaceable | Business rules in our code; the app reaches Supabase only through its own data layer | Moving to Railway later means moving the data and that layer, not the app | Calling Supabase from the screens |
| Platform | Installable web app (PWA), built with Flutter | One link, an icon on the home screen, US$0, instant updates; the same Flutter code can go to the stores later | Plain web page (doesn't feel like an app); store apps (US$99/year Apple, US$25 Google, review per change) |
| How an exercise is shown | An exercise catalog: each entry has the exercise's name variants, a short reference video from the internet (YouTube, embedded at the right second, looping), 2–3 short cues, and a scaling or substitute | A 3-second loop plus cues answers ~99% of "how is this done?" for athletes training remotely | Recording our own clips; cutting or downloading others' videos; ExerciseDB (paid API key, gym-oriented catalog) |
| Repositories | One public repo: the functional tests moved from the private `crossfit-app-e2e` into `e2e/`, with their history, and run in the check of every pull request | One place for code and tests, as in FL1; nothing in the tests is secret (the PIN comes from a gitignored `.env` or a repository secret; the sheet ID and the Apps Script URL were already public); GitHub Pages and branch protection stay free | Making the repo private (Pages and branch protection need GitHub Pro, ≈ US$4/month, or moving hosting to Cloudflare Pages); a new repo replacing both (loses history and pull requests, and the app's URL changes) |
| AI | Only on our side, to draft catalog entries (match name variants, propose cues and a scaling), run locally with Ollama; **the coach reviews every entry** before athletes see it | It's useful and a way to learn, without risk to athletes or per-use cost | AI inside the athlete's app (key exposed, cost per use, answers that bypass the coach) |

---

## What's still undecided

1. **The first version's scope**: what it does, for whom (Ale and Fabi
   first?), and what happens with the current viewer and `~/crossfit_flutter`.
2. **For the coach, when the project is presented to him**: how many
   athletes and how their plans are organized (one sheet each, or tabs); an
   olympic-lifting plan as an example; how he'd like to approve catalog
   entries.
3. **Design proposals, to be brought to the user** (no answer needed until
   then): where athlete notes go in the sheet, how a reply is marked as
   "replace" or "advise" and whether the original stays visible, how a
   standing note ends and where the athlete sees it, and how to simplify
   Dotta Crew's note fields.

---

## Debt and risks

| Item | Status |
| --- | --- |
| **No unit tests in the repo** | The viewer was built without them; its rules (weight split, exercise naming, week dates) sit as private functions in `mobile/lib/week/week_app.dart`. The rule applies from now on; whether the viewer's rules get tests depends on how much of it survives into the new app. |
| **Branch protection on `master`** | Pending the user's approval. The repo is public, so GitHub's free plan allows requiring the `check` workflow before merging — stronger than FL1's merge script, which exists only because FL1's repo is private. |
| **`develop` branch** | Obsolete with one branch per change from `master`. Deleting it (local and remote, plus `macbook-works`) is pending the user's approval. |
| **Service account write access** | As of 2026-09-29 (Drive permissions on the sheet): the user's Google account is an editor; the service account and Fabita's account are readers. Writing notes to the sheet needs either the coach to make the service account an editor, or the writes to run as the user's account. To be decided when the sheet adapter is built. |
| **The old `crossfit-app-e2e` repo** | To be archived (read-only, reversible) once this move is merged; deleted later if nothing is missed. |
| **`COACH_PIN` secret** | The functional tests in CI skip the coach part until the user adds the `COACH_PIN` repository secret. |
| **Viewer leftovers** | `apps_script/Code.gs` and "Mi semana — datos" (notes, coach edits with PIN) serve the viewer only; they go away with it. |

---

## Phase 0 — The week viewer ✅ **live**

A static page that shows the current week from the coach's sheet. Kept here
because it's what runs today.

- [x] `tools/sheet_to_json.py` — reads every month tab with the service
      account and writes `workouts.json`; month tabs matched by prefix
      (`Sep`, `Sept`, `Septi`, `Agos`…); skipped tabs are logged, never
      dropped silently
- [x] Viewer (`mobile/lib/week/`) — opens on the week containing today;
      ◀ ▶ to browse; Estructura / Fuerza / WOD sections; `N RxC` badge; done
      checkbox per day
- [x] Week dates ("Semana 4 · 21 – 27 sep") — Semana 1 = the week holding
      the 1st of the month, +7 days per week; tabs shown as "Septiembre 2026"
      with the year inferred from tab order
- [x] Weights by person ("¿Quién eres?"): Ale = heavier of each `(X/Y)`,
      Fabita = lighter, by value
- [x] Always fresh: cache-busting fetch, built with `--pwa-strategy=none`
- [x] GitHub Action: builds and deploys on push to `master`, daily at
      05:00 UTC, or manually
- [x] Weight notes per person and day, shared across devices, with the day's
      exercises as ready-made rows
- [x] Coach profile (PIN) edits any day and both notes, as an overlay shown
      while the day is unchanged in the sheet
- [x] `apps_script/Code.gs` bound to "Mi semana — datos", tabs `Notas` and
      `Ediciones`
- [x] End-to-end check (Playwright) in `e2e/` (a private repo until 2026-10-28)

### The viewer's decisions

Kept for the record. Those marked **superseded** no longer hold for the
redefined app.

| Decision | Reason |
|---|---|
| Static page + scheduled Action instead of a backend — **superseded** by the Supabase decision | Single user, private sheet; nothing needed to run 24/7 |
| Python script for the parser | ~150 lines, runs in the Action in seconds |
| Current week = last tab of the current month | The coach abbreviates tab names and sometimes repeats a month |
| No remembered position | The page must always open on this week |
| Who-am-I and done state in the browser — **superseded** by sign-in | Two people, each on their own phone |
| Weight by value, not by column position | "Ale gets the heavier one" is the actual rule |
| "Semana 1" = week containing the 1st of the month | Checked against the sheet on 2026-09-21 |
| Year inferred from tab order | Tab titles have no year |
| Backend and multi-user app deleted from the repo (2026-09-21) | Not deployed, only noise; the history is in git |
| Notes and coach edits through one Apps Script (2026-09-29) — **superseded** | Shared across devices with no server of our own |
| All writes go to "Mi semana — datos", never the coach's sheet — **superseded** for the shared plan sheet, which the coach opened for writing | His sheet was his |
| Coach edits stored as overlays with the day's original ("Base") | His sheet stayed untouched, and his later change wins |
| Notes as plain text, one `exercise: value` line | Readable straight in the datos tab |
