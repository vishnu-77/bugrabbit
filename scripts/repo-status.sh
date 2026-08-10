#!/usr/bin/env bash
#
# repo-status.sh — summarise docs/backlog.md (FIX-NNN rows) by status, and, if the active repo's
# host (via scripts/host.sh) is authed, its open auto-fix issues and open PRs.
#
# Usage: repo-status.sh [TARGET_DIR]
#   TARGET_DIR (optional) — active target repo for the tracker half. Default: $VP_ACTIVE_REPO.
#
set -uo pipefail

VP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKLOG="$VP_ROOT/docs/backlog.md"
FINDINGS="$VP_ROOT/docs/findings.md"
TARGET="${1:-${VP_ACTIVE_REPO:-}}"
source "$VP_ROOT/scripts/resolve-repo.sh"
TARGET="$(resolve_repo "${1:-}")" || exit $?
HOST_SH="$VP_ROOT/scripts/host.sh"

echo "== backlog status ($BACKLOG) =="
if [ -f "$BACKLOG" ]; then
  ROWS=$(grep -E '^\|[[:space:]]*FIX-[0-9]+' "$BACKLOG" || true)
  if [ -z "$ROWS" ]; then
    echo "  (no FIX-NNN rows yet)"
  else
    for st in READY IN-PROGRESS IN-REVIEW DONE PARTIAL BLOCKED; do
      n=$(grep -cE "\|[[:space:]]*${st}[[:space:]]*\|" <<< "$ROWS" || true)
      printf "  %-12s %s\n" "$st" "${n:-0}"
    done
  fi
else
  echo "  (backlog not found)"
fi

echo "== findings (open critical/high) =="
if [ -f "$FINDINGS" ]; then
  grep -E '^\|[[:space:]]*F-[0-9]+' "$FINDINGS" | grep -Ei 'critical|high' | grep -i 'open' || echo "  (none open)"
else
  echo "  (findings ledger not found)"
fi

HOST="$(VP_ACTIVE_REPO="$TARGET" "$HOST_SH" detect)"
echo "== $HOST tracker (active repo) =="
if [ "$HOST" = "unknown" ]; then
  echo "  (origin remote is not a recognised host — set VP_HOST=github|gitlab to override)"
elif ! VP_ACTIVE_REPO="$TARGET" "$HOST_SH" auth-status >/dev/null 2>&1; then
  VP_ACTIVE_REPO="$TARGET" "$HOST_SH" auth-status 2>&1 | sed 's/^/  /'
else
  REPO_SLUG="$(VP_ACTIVE_REPO="$TARGET" "$HOST_SH" remote-slug)" || exit $?

  echo "-- open issues labelled auto-fix --"
  ISSUES="$(VP_ACTIVE_REPO="$TARGET" "$HOST_SH" issue-list --state open --label auto-fix 2>/dev/null)"
  if [ -z "$ISSUES" ]; then echo "  (none)"; else
    printf '%s\n' "$ISSUES" | awk -F'\t' '{printf "  #%-6s %-8s %s\n", $1, $2, $3}'
  fi

  echo "-- open PRs --"
  PRS="$(VP_ACTIVE_REPO="$TARGET" "$HOST_SH" pr-list --state open 2>/dev/null)"
  if [ -z "$PRS" ]; then echo "  (none)"; else
    printf '%s\n' "$PRS" | awk -F'\t' '{printf "  #%-6s %-8s %-40s %s\n", $1, $2, $3, $4}'
  fi

  echo "-- stale-close candidates (backlog says DONE/PARTIAL, tracker still shows OPEN) --"
  if [ -f "$BACKLOG" ]; then
    FOUND_STALE=0
    # FIX-NNN rows for this repo, status DONE or PARTIAL, with a real issue number.
    # Process substitution (not a pipe) so FOUND_STALE survives outside the loop.
    while IFS='|' read -r _ fixid repo issue _title _sev status _rest; do
      repo="$(echo "$repo" | xargs)"; issue="$(echo "$issue" | xargs)"; status="$(echo "$status" | xargs)"
      [ "$repo" = "$REPO_SLUG" ] || continue
      case "$status" in DONE*|PARTIAL*) ;; *) continue ;; esac
      [[ "$issue" =~ ^[0-9]+$ ]] || continue
      state="$(VP_ACTIVE_REPO="$TARGET" "$HOST_SH" issue-state "$issue" 2>/dev/null || true)"
      if [ "$state" = "open" ]; then
        echo "  #$issue ($(echo "$fixid" | xargs)) — backlog says $status, tracker issue still open"
        FOUND_STALE=1
      fi
    done < <(grep -E '^\|[[:space:]]*FIX-[0-9]+' "$BACKLOG")
    [ "$FOUND_STALE" -eq 0 ] && echo "  (none — backlog and tracker agree)"
  else
    echo "  (backlog not found)"
  fi
fi
