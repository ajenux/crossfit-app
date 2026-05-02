#!/bin/bash
#
# update-plan.sh — updates PLAN.md using Claude based on recent commits and current state
# Usage: ./scripts/update-plan.sh
# Run this before pushing to develop or master.
#

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
PLAN_FILE="$REPO_ROOT/PLAN.md"

if [ ! -f "$PLAN_FILE" ]; then
  echo "PLAN.md not found at $PLAN_FILE"
  exit 1
fi

echo "Reading recent commits and project state..." >&2

RECENT_COMMITS=$(git log --oneline -20)
CURRENT_PLAN=$(cat "$PLAN_FILE")
BRANCH=$(git rev-parse --abbrev-ref HEAD)
DATE=$(date +%Y-%m-%d)

echo "Asking Claude to update PLAN.md..." >&2

UPDATED=$(claude -p \
  "You are a project plan maintainer for a CrossFit management app (Spring Boot 4 backend + Flutter frontend).

Your job is to update the PLAN.md file based on recent git commits. Be precise:
- Mark items as done [x] if recent commits clearly implement them
- Update the 'Last updated' date to $DATE
- Update 'Active branch' to $BRANCH
- Add new pending items if commits introduce something unfinished or referenced in TODOs
- Do NOT change formatting, headings, or table structure
- Do NOT invent items — only act on what the commits actually show
- Output ONLY the updated PLAN.md content, no explanation

Current PLAN.md:
$CURRENT_PLAN

Recent commits (newest first):
$RECENT_COMMITS
" 2>/dev/null)

if [ -z "$UPDATED" ]; then
  echo "Claude did not return content — PLAN.md was not modified."
  exit 1
fi

echo "$UPDATED" > "$PLAN_FILE"
echo "PLAN.md updated successfully."
echo ""
echo "Review the changes:"
git diff "$PLAN_FILE"
