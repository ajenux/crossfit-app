# Plan — Mi semana

Goal: Ale and Fabita see their current training week from the coach's Google
Sheet without opening the sheet. One screen, no login, no backend, no paid hosting.

**Live:** https://ajenux.github.io/crossfit-app
**Branch:** `develop` (merge to `master` deploys)
**Last updated:** 2026-09-21

---

## Done

- [x] `tools/sheet_to_json.py` — reads every month tab of the sheet with the
      service account and writes `workouts.json` (weeks, days, section markers)
- [x] Month tabs matched by prefix (`Sep`, `Sept`, `Septi`, `Agos`…); skipped
      tabs are logged, never dropped silently
- [x] Viewer (`mobile/lib/week/`) — opens on the last tab of the current
      calendar month, last week; ◀ ▶ to browse; Estructura / Fuerza / WOD
      sections; `N RxC` badge; done checkbox per day
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
- [x] README and CLAUDE.md describe this and only this

## Pending

- [ ] Nothing. Use it for a few weeks; add something only if it's actually missing.

## Ideas (only if they turn out to matter)

- Show the date range of the week next to "Semana N"

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
| Year inferred from tab order | Tab titles have no year; walking backwards and decrementing when the month goes up is unambiguous for a sheet kept in order |
| Backend and multi-user app deleted from the repo (2026-09-21) | They were not deployed and only added noise; the history is still in git if ever needed |
