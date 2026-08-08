#!/usr/bin/env bash
#
# poll-issues.sh — cron helper. Poll the active repo's open issues (GitHub or Bitbucket, via
# scripts/host.sh) and record any NOT yet tracked into docs/issue-log.md (the "seen" ledger).
# Idempotent + dedup: an owner/repo#issue key already present in the ledger is never appended again.
# Prints the count of newly-seen issues.
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
HOST_SH="$VP_ROOT/scripts/host.sh"

VP_ACTIVE_REPO="$TARGET" "$HOST_SH" auth-status >/dev/null || exit 2

# Seed the ledger if missing.
if [ ! -f "$LOG" ]; then
  {
    echo "# Issue log — cron-tracked issues (GitHub or Bitbucket; seen set)"
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
REPO_SLUG="$(VP_ACTIVE_REPO="$TARGET" "$HOST_SH" remote-slug)" || exit $?

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
# Tab-separated: number \t state \t title
while IFS=$'\t' read -r num _state title; do
  [ -z "$num" ] && continue
  key="$REPO_SLUG#$num"
  if grep -Fqx "$key" <<< "$SEEN"; then continue; fi
  # sanitise pipes in title
  title="${title//|/-}"
  printf '| %s | %s | %s | %s | UNTRIAGED |\n' "$num" "${REPO_SLUG:-?}" "$title" "$NOW" >> "$LOG"
  NEW=$((NEW+1))
done < <(VP_ACTIVE_REPO="$TARGET" "$HOST_SH" issue-list --state open "${LABEL_ARG[@]}" 2>/dev/null)

echo "poll-issues: $NEW newly-seen issue(s) recorded in $LOG"
[ "$NEW" -gt 0 ] && echo "  → run /status-check or /autofix-issues to process UNTRIAGED rows."
exit 0
