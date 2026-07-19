#!/usr/bin/env bash
#
# poll-issues.sh — cron helper. Poll the active repo's open GitHub issues and record any NOT yet
# tracked into docs/issue-log.md (the "seen" ledger). Idempotent + dedup: an owner/repo#issue key
# already present in the ledger is never appended again. Prints the count of newly-seen issues.
#
# Usage: poll-issues.sh [TARGET_DIR] [--label <label>]
#   TARGET_DIR default: $VP_ACTIVE_REPO. --label default: none (all open issues).
#
set -uo pipefail

VP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$VP_ROOT/docs/issue-log.md"
source "$VP_ROOT/scripts/resolve-repo.sh"
TARGET="$(resolve_repo "${1:-}")" || exit $?
LABEL=""
[ "${2:-}" = "--label" ] && LABEL="${3:-}"

command -v gh >/dev/null 2>&1 || { echo "FAIL: gh not installed" >&2; exit 2; }
gh auth status >/dev/null 2>&1 || { echo "FAIL: gh not authed" >&2; exit 2; }

# Seed the ledger if missing.
if [ ! -f "$LOG" ]; then
  {
    echo "# Issue log — cron-tracked GitHub issues (seen set)"
    echo
    echo "Append-only. Dedup key: owner/repo#issue. Status: UNTRIAGED | TRIAGED | WORKING | DONE | SKIPPED."
    echo "Populated by \`scripts/poll-issues.sh\` (cron) and updated by /work-issue, /status-check."
    echo
    echo "| issue | repo | title | first_seen | status |"
    echo "|-------|------|-------|-----------|--------|"
  } > "$LOG"
fi

LABEL_ARG=()
[ -n "$LABEL" ] && LABEL_ARG=(--label "$LABEL")
REPO_SLUG="$(git -C "$TARGET" remote get-url origin 2>/dev/null | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')"
[ -n "$REPO_SLUG" ] || { echo "FAIL: could not derive owner/repo from origin remote" >&2; exit 2; }

# Composite keys already in the ledger (repository + issue number).
SEEN="$(awk -F'|' '
  /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
    issue=$2; repo=$3
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", issue)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", repo)
    print repo "#" issue
  }
' "$LOG" | sort -u)"

NEW=0
NOW="$(date +%F)"
# Tab-separated: number \t title
while IFS=$'\t' read -r num title; do
  [ -z "$num" ] && continue
  key="$REPO_SLUG#$num"
  if grep -Fqx "$key" <<< "$SEEN"; then continue; fi
  # sanitise pipes in title
  title="${title//|/-}"
  printf '| %s | %s | %s | %s | UNTRIAGED |\n' "$num" "${REPO_SLUG:-?}" "$title" "$NOW" >> "$LOG"
  NEW=$((NEW+1))
done < <(gh issue list -R "$REPO_SLUG" --state open "${LABEL_ARG[@]}" --json number,title \
           --jq '.[] | "\(.number)\t\(.title)"' 2>/dev/null)

echo "poll-issues: $NEW newly-seen issue(s) recorded in $LOG"
[ "$NEW" -gt 0 ] && echo "  → run /status-check or /autofix-issues to process UNTRIAGED rows."
exit 0
