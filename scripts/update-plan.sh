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

Your job is to update the PLAN.md file based on recent git commits. Rules:
- Mark items as done [x] if recent commits clearly implement them
- Update the 'Last updated' date to $DATE
- Update 'Active branch' to $BRANCH
- Add new pending items only if commits introduce something clearly unfinished
- Do NOT change formatting, headings, or table structure
- Do NOT invent items — only act on what the commits actually show
- CRITICAL: Start your response with exactly '# Project Plan' and output NOTHING else.
  No explanation before, no explanation after, no code fences, no summary.
  Raw file content only.

Current PLAN.md:
$CURRENT_PLAN

Recent commits (newest first):
$RECENT_COMMITS
" 2>/dev/null)

if [ -z "$UPDATED" ]; then
  echo "Claude did not return content — PLAN.md was not modified."
  exit 1
fi

# Extract only content from the first markdown heading to the end of the table.
# Strips preamble, code fences, and any trailing explanation text.
CLEANED=$(echo "$UPDATED" | awk '
  /^# /        { found=1 }
  /^```/        { next }
  found         { print }
' | sed '/^\*\*Changes made/,$d')

if [ -z "$CLEANED" ]; then
  echo "Could not extract clean content — PLAN.md was not modified."
  exit 1
fi

echo "$CLEANED" > "$PLAN_FILE"
echo "PLAN.md updated successfully."
echo ""
echo "Review the changes:"
git diff "$PLAN_FILE"
