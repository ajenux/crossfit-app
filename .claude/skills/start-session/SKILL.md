---
name: start-session
description: Get up to date at the start of a work session, on whatever machine — what changed, what's open, how the deploy is, what's next in the plan. Use when the user says "arrancamos", "empecemos", "poneme al día", "leé el plan y hacé un fetch", or invokes /start-session.
---

# Starting a session

Work moves between machines, and a clone can say "clean" while being
several merges behind; `PLAN.md` is the one place the state travels in.
This gets the session up to date before anything gets built. It reads and
reports; it changes nothing.

`CLAUDE.md` is already loaded on its own.

## Steps

1. **Where the repository stands.**
   `git fetch --prune`, `git status -sb`, `git log --oneline HEAD..origin/master`
   (merges this clone hasn't got), and `gh pr list` (work already open — a
   piece marked pending in `PLAN.md` may be in a pull request). If `master`
   is behind and the tree is clean, `git checkout master && git pull`.

2. **What's decided and what's next.** In `PLAN.md`, "Current status",
   "What comes next, in order" and "What's still undecided".

3. **How the deploy is.** `gh run list --workflow deploy-web.yml --limit 1`
   and `gh run list --workflow check.yml --limit 1`. A failed one goes first
   in the summary.

## The summary, in Spanish, short

- **Novedades**: merges since the last session, open pull requests, the
  deploy's and the check's state — only what changed or needs attention.
- **Pendiente**: the next step in "What comes next", and any open question
  that blocks it.
- **Sugerencia**: what to work on today, and why — one recommendation, not
  a list.

Say what's resolved once and don't repeat it; if nothing changed, say so in
one line.
