# How this project is tested

Three layers, and each one answers a question the others can't. This
describes **what exists** and the rule for what comes; where the project is
heading is in [PLAN.md](PLAN.md).

| Layer           | Where                                              | Runs against                                         | Answers                                                                 | How many |
| --------------- | -------------------------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------- | -------- |
| **Unit**        | `mobile/test/` (Dart), `tools/` (Python, pytest)   | Nothing. Pure functions.                             | Is the business rule correct?                                           | 0        |
| **Integration** | Next to the adapter or data layer it covers        | A fixture copy of the sheet; a local Supabase        | Do the pieces fit together? Does a role that can't get refused?        | 0        |
| **Functional**  | `crossfit-app-e2e/app.spec.mjs` (private repo)     | The published page, in Chrome                        | Does this look right and work, as a person would use it?                | 15       |

```bash
cd mobile && flutter analyze      # types and lint
cd mobile && flutter test         # unit (once mobile/test/ exists)
cd ../crossfit-app-e2e && npx playwright test   # functional, see its README
```

**Functional tests live in a private repo on purpose**: they read the real
sheet and write to real spreadsheets, with the service account's key, and
this repo is public.

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
| On every pull request and push to `master` | `.github/workflows/check.yml`: `flutter analyze`, the unit tests, the Python tools compiled | Did what was just written break something? |
| Before merging | The functional tests in `crossfit-app-e2e`, by hand | Does it still work as a person uses it? |

A nightly run of everything, like FL1's, is not set up: with the viewer
alone it would add little. It becomes worth it once the app depends on dates
and on a database that changes with nobody touching the code.

## What's covered today

- **The viewer, functionally**: the 15 tests in `crossfit-app-e2e` cover the
  published `workouts.json` against the sheet, opening on today's week,
  weights per person, notes, coach edits, and that the coach's sheet didn't
  change during the run. Its README lists them.
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
