# CrossFit App

An app where an athlete sees what their coach planned for today, split into
the day's phases, looks up how an exercise is done, and leaves notes the
coach reads and answers. The coach writes the plans. Today the plans live in
the coach's Google Sheet; the app adapts to that sheet without making it its
data model.

`PLAN.md` says where the project is heading and is **the north to follow**:
nothing gets built that isn't in it, and nothing in it changes without the
user deciding so. `README.md` explains how what is deployed works.
`TESTING.md` explains how it is tested.

What is live today is still the week viewer (`https://ajenux.github.io/crossfit-app`),
described in `README.md`. The redefined app in `PLAN.md` replaces it.

## What's non-negotiable

**Every new feature ships with its set of tests**, in whichever layers apply.
The detail is in `TESTING.md`; the summary:

| What gets added                         | Where its test goes                                                                                                   |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| A business rule                         | The domain layer, as a pure function with its own unit test                                                           |
| Something that reads or writes the coach's sheet | The sheet adapter's tests, against a fixture copy of the sheet's real layout                                 |
| Something that touches the database or a role | Integration test: it does what it says, and a role that can't gets refused                                      |
| A screen                                | Functional test (Playwright, in `e2e/`): reachable, visible, no overflow at 390 px, with a screenshot |

**Never close a task with "open it and take a look."** If it can't be
claimed that something works without a person looking at it, a functional
test is missing.

**Never write to a sheet that isn't ours to write.** The plan sheet Ale and
Fabi share (`1LUks…`) can be written to: the coach granted it. Any other
coach sheet is read-only until its coach says otherwise.

## Done means

All five, not four. Nothing counts as closed before that.

1. **The check is green**: `flutter analyze`, the unit and integration
   tests, and the functional tests in `e2e/` — all of them run in the `check`
   workflow of every pull request.
2. **The three documents are up to date**: `PLAN.md` (status and
   decisions), `README.md` (how it works), `TESTING.md` (what each layer
   covers). All three, not whichever one comes to mind.
3. **Reread what the documents already claimed about what got touched.**
   Adding the new part isn't enough: search the three for the change's words
   and fix whatever became false.
4. **If the branch got rebased or redone, verify that every fix survived.**
5. **Say what was left out.** If something in scope didn't make it, say which
   and why; shrinking the work is the user's decision, not the implementer's.

## How the work gets done

- **One branch per change, cut from `master`, a pull request, and a merge
  commit** — never fast-forward: the merge commit is the anchor for
  reverting in one piece. `master` deploys.
- **Nothing red gets into `master`.** The `check` workflow runs on every
  pull request, and branch protection on `master` requires its `check` and
  `e2e` jobs green before merging, for admins too. Nobody pushes to `master`
  directly: GitHub refuses it, and the hook in `.githooks/` says so earlier,
  enabled with `git config core.hooksPath .githooks`.
- **Staging, committing, pushing and merging are the user's decision.**
  Ask first, every time. No merging in passing, nor "to try it."
- **`git fetch` before branching.** More than one machine works on this repo.
- **`PLAN.md` gets updated with every change of status, in the same pull
  request.** It's the only place that travels with the code between machines.
- **A session starts with the `start-session` skill** (`.claude/skills/`).
- **Decisions get written down with what was ruled out.** The alternative was
  almost never absurd, and it has to be possible to revisit it.
- **Verify against real data before claiming something works.** The sheet,
  the coach's Dotta Crew app, today's date: look, don't assume. Anything
  skipped or ignored gets said; data is never dropped silently.
- **Don't ask the user what can be checked.** The sheet and the coach's app
  answer most questions about the coach's flow.
- **No over-engineering.** Practicality and usability come first; the
  simplest thing that keeps the core clean wins.

## Language

Everything internal — code, comments, identifiers, file names, commit
messages, and the documents (`README.md`, `PLAN.md`, `TESTING.md`, this
file) — goes in English, in the impersonal third person. Everything the
athlete or the coach sees — the interface, its messages, screenshots — goes
in Spanish. Anything stored or sent over the wire keeps its name once
chosen: renaming it is a data migration. Talk to the user in the language
they use.

## Two guarantees the project gives itself

- **Business rules live exactly once**, in the domain layer, as pure
  functions, and every other layer uses them without copying them. If a rule
  can't be tested without standing anything up, it's in the wrong place.
- **The edges are adapters.** The coach's sheet is reached only through the
  sheet adapter, and the database only through the app's own data layer —
  the screens never talk to Supabase directly. When the coach leaves the
  sheet, or the project leaves Supabase, only that adapter changes.
