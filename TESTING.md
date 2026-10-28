# How this project is tested

Three layers, and each one answers a question the others can't. This
describes **what exists** and the rule for what comes; where the project is
heading is in [PLAN.md](PLAN.md).

| Layer           | Where                                              | Runs against                                         | Answers                                                                 | How many |
| --------------- | -------------------------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------- | -------- |
| **Unit**        | `mobile/test/` (Dart), `tools/` (Python, pytest)   | Nothing. Pure functions.                             | Is the business rule correct?                                           | 0        |
| **Integration** | Next to the adapter or data layer it covers        | A fixture copy of the sheet; a local Supabase        | Do the pieces fit together? Does a role that can't get refused?        | 0        |
| **Functional**  | `e2e/app.spec.mjs`                                 | The built page, in Chrome, with the real sheet       | Does this look right and work, as a person would use it?                | 16       |

```bash
cd mobile && flutter analyze      # types and lint
cd mobile && flutter test         # unit (once mobile/test/ exists)
cd e2e && npx playwright test     # functional, against the published page; see e2e/README.md
```

**Functional tests run against the real thing**: they read the real sheet and
write only to a sandbox tab of "Mi semana — datos", with the service
account's key from a gitignored file locally and from the repository's
secrets in CI. They lived in a private repo until 2026-10-28; nothing in them
is secret, and one repo lets them run on every pull request.

## Why three layers and not one

**Unit tests are cheap and don't prove the system works.** The weight split
can be flawless and the sheet adapter never hand it the right line.

**Integration tests prove the pieces fit, not that it looks right.** They
can check that a note reaches the sheet and that an athlete can't read
another athlete's notes; they can't see a card overflowing a phone screen.

**Functional tests are the only ones that replace a person looking.** They
open the page, click where a person would, measure real positions, and leave
a screenshot.

## When each thing runs

| When | What runs | Answers |
| --- | --- | --- |
| On every pull request and push to `master` | `.github/workflows/check.yml`: `flutter analyze`, the unit tests, the Python tools compiled; then the functional tests against that change's own build, served locally | Did what was just written break something, as a person would see it? |

### What CI costs, and the rules that keep it at zero

FL1 ran out of GitHub Actions storage twice (2026-09-28 at 100% of the
account's 0.5 GB, 2026-10-14 at 90%): screenshot evidence of ~21 MB per push,
kept for days, and storage billed by the hour. That quota is **per account**,
shared with FL1 and every other private repo, so these rules hold here too:

- **Minutes cost nothing here**: standard runners are free in public repos.
  The account's monthly minutes belong to the private repos.
- **A newer push cancels the older run** (`cancel-in-progress`), except where
  runs share the sandbox tab, which queue instead.
- **Every job has a `timeout-minutes`**: a run that hangs with no cap burns
  an hour silently.
- **Any artifact gets `retention-days: 1`** (a run is looked at while it
  matters; an older one is a re-run away), **and `continue-on-error: true`**:
  storage running out must never turn the check red over the account instead
  of the code. No artifacts are uploaded today.
- **The cache isn't the account's storage**: the Flutter and npm caches use
  the per-repository cache allowance (10 GB), separate from the quota above.

A nightly run of everything, like FL1's, is not set up: with the viewer
alone it would add little. It becomes worth it once the app depends on dates
and on a database that changes with nobody touching the code.

## What's covered today

- **The viewer, functionally**: the 16 tests in `e2e/` cover the
  published `workouts.json` against the sheet, opening on today's week,
  weights per person, notes, coach edits, and that the coach's sheet didn't
  change during the run. `e2e/README.md` lists them. Without the `COACH_PIN`
  secret, the coach part is skipped.
- **Nothing at unit or integration level.** The viewer's rules live as
  private functions in `mobile/lib/week/week_app.dart`.

## The rule, for what's next

**Every new feature ships with its set of tests, in whichever layers apply.**
It isn't ceremony: it's what keeps the project workable months from now, and
what lets "it's done" mean something without anyone opening the app.

1. **Does it have a business rule?** It goes to the domain layer, as a pure
   function, with its own unit tests. If the rule can't be tested without
   standing anything up, it's in the wrong place.
2. **Does it read or write the coach's sheet?** A test of the sheet adapter
   against a fixture copy of the sheet's real layout — taken from the sheet,
   not invented.
3. **Does it touch the database or a role?** An integration test: that it
   does what it says, and that a role that can't — an athlete reading
   another athlete, an athlete acting as the coach — gets refused.
4. **Is it a screen?** A functional test: reachable, what should be visible
   is, no overflow at 390 px wide, and an evidence screenshot.

**A test that never failed proves little.** When a test is added for a rule,
break the rule once and confirm the test goes red.
