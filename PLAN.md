# Plan — Mi semana

Goal: Ale and Fabita see their current training week from the coach's Google
Sheet without opening the sheet. One screen, no login, no backend, no paid hosting.
The coach's sheet is only ever read; the few writes go to our own spreadsheet
"Mi semana — datos".

**Live:** https://ajenux.github.io/crossfit-app
**Branch:** `develop` (merge to `master` deploys)
**Last updated:** 2026-09-30

---

## Done

- [x] `tools/sheet_to_json.py` — reads every month tab of the sheet with the
      service account and writes `workouts.json` (weeks, days, section markers)
- [x] Month tabs matched by prefix (`Sep`, `Sept`, `Septi`, `Agos`…); skipped
      tabs are logged, never dropped silently
- [x] Viewer (`mobile/lib/week/`) — opens on the week containing today;
      ◀ ▶ to browse; Estructura / Fuerza / WOD sections; `N RxC` badge; done
      checkbox per day
- [x] Week dates next to the label ("Semana 4 · 21 – 27 sep") — Semana 1 =
      week holding the 1st of the month, +7 days per week
- [x] Tabs shown as "Septiembre 2026" — year inferred from tab order
- [x] Weights by person: first visit asks "¿Quién eres?" (Ale / Fabita Rumana
      Portillo), saved in the browser; Ale = heavier of each `(X/Y)`, Fabita =
      lighter; chips to change it later
- [x] Always fresh: cache-busting fetch of the JSON, built with
      `--pwa-strategy=none` (no service worker)
- [x] GitHub Action: generates the JSON and deploys on push to `master`,
      daily at 05:00 UTC, or manually; `GOOGLE_CREDENTIALS_JSON` secret set
- [x] Verified in the browser against the live URL: shows Septi → Semana 4
      (week of 2026-09-21)
- [x] Weight notes ("Pesos logrados") per person and day, shared across
      devices; each person edits their own line. The editor offers the day's
      exercises as ready-made rows (Fuerza lines, ramp-up Estructura lines,
      one WOD row), named plainly ("Deadlift")
- [x] Coach profile ("Entrenador", PIN) edits any day and both notes; the
      edit is shown on top of the sheet while the day is unchanged in it
- [x] `apps_script/Code.gs` — Apps Script web app bound to "Mi semana —
      datos" (`@OnlyCurrentDoc`), tabs `Notas` and `Ediciones`; its URL is the
      `APPS_SCRIPT_URL` repo variable; without it the page is a plain viewer
- [x] The week shows before notes arrive; "Guardando…" while a save is in
      progress
- [x] End-to-end check (Playwright) kept in a separate private repo
- [x] README and CLAUDE.md describe this and only this

## Pending

- [ ] Nothing. Use it for a few weeks; add something only if it's actually missing.

## Ideas (only if they turn out to matter)

- (none right now)

---

## Decisions

| Decision | Reason |
|---|---|
| Static page + scheduled Action instead of a backend | Single user, private sheet: a service account in a GitHub secret reads it; nothing needs to run 24/7 and nothing costs money |
| Python script for the parser | ~150 lines, runs in the Action in seconds with two pip packages; no need to build the Java project to read a sheet |
| Current week = last tab of the current month | The coach abbreviates tab names and sometimes repeats a month; matching by calendar month and taking the last one is what a person would do |
| No remembered position | The page must always open on this week; browsing history was noise |
| Who-am-I and done state in the browser | Two people, each on their own phone; a shared store would be a backend again |
| Weight by value, not by column position | "Ale gets the heavier one" is the actual rule; it survives the coach writing the pair the other way round |
| "Semana 1" = week containing the 1st of the month | Checked against the sheet: today (Mon 2026-09-21) is the coach's Semana 4 of September, which only fits this convention; it also explains why months have 4–5 weeks |
| Year inferred from tab order | Tab titles have no year; walking backwards and decrementing when the month goes up is unambiguous for a sheet kept in order |
| Backend and multi-user app deleted from the repo (2026-09-21) | They were not deployed and only added noise; the history is still in git if ever needed |
| Notes and coach edits through one Apps Script (2026-09-29) | Shared across devices without a server of our own or paid hosting; asked for explicitly |
| All writes go to "Mi semana — datos", never the coach's sheet | His sheet is his; `@OnlyCurrentDoc` makes the script unable to open it even by mistake |
| Coach edits stored as overlays with the day's original ("Base") | His sheet stays untouched, and once he changes the day there his version wins, so an old edit never hides a newer change |
| Notes as plain text, one `exercise: value` line | Readable straight in the datos tab; no schema to maintain |
