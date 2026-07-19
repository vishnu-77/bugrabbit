#!/usr/bin/env bash
#
# repo-status.sh — summarise docs/backlog.md (FIX-NNN rows) by status, and, if gh is authed,
# the active target repo's open auto-fix issues and open PRs.
#
# Usage: repo-status.sh [TARGET_DIR]
#   TARGET_DIR (optional) — active target repo for the gh half. Default: $VP_ACTIVE_REPO.
#
set -uo pipefail

VP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKLOG="$VP_ROOT/docs/backlog.md"
FINDINGS="$VP_ROOT/docs/findings.md"
TARGET="${1:-${VP_ACTIVE_REPO:-}}"
source "$VP_ROOT/scripts/resolve-repo.sh"
TARGET="$(resolve_repo "${1:-}")" || exit $?

echo "== backlog status ($BACKLOG) =="
if [ -f "$BACKLOG" ]; then
  ROWS=$(grep -E '^\|[[:space:]]*FIX-[0-9]+' "$BACKLOG" || true)
  if [ -z "$ROWS" ]; then
    echo "  (no FIX-NNN rows yet)"
  else
    for st in READY IN-PROGRESS IN-REVIEW DONE BLOCKED; do
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

echo "== github (active repo) =="
if ! command -v gh >/dev/null 2>&1; then
  echo "  (gh not installed — brew install gh)"
elif ! gh auth status >/dev/null 2>&1; then
  echo "  (gh not authed — gh auth login)"
else
  REPO_SLUG="$(git -C "$TARGET" remote get-url origin 2>/dev/null | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')"
  if [ -z "$REPO_SLUG" ]; then
    echo "  (no origin remote on $TARGET)"
  else
    echo "-- open issues labelled auto-fix --"
    gh issue list -R "$REPO_SLUG" --label auto-fix --state open 2>/dev/null || echo "  (none)"
    echo "-- open PRs --"
    gh pr list -R "$REPO_SLUG" --state open 2>/dev/null || echo "  (none)"
  fi
fi
