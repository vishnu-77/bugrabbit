#!/usr/bin/env bash
#
# find-bugs.sh — thin helper: compute the diff under review and hand it to the pr-reviewer.
# Used locally and by the CI bug-finder workflow (self-hosted runner, local Claude Code — no API key).
# This script only GATHERS inputs and invokes the reviewer; all judgement lives in the agent + rubric.
#
# Usage:
#   find-bugs.sh pr   <pr-number>         # review a PR (via scripts/host.sh — GitHub or Bitbucket)
#   find-bugs.sh range <base>..<head>     # review a commit range
#   find-bugs.sh diff                     # review the working tree (default)
#
# Env: VP_ROOT (auto), TARGET_DIR (default: PWD).
#
set -uo pipefail

VP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$VP_ROOT/scripts/resolve-repo.sh"
TARGET_DIR="$(resolve_repo "${TARGET_DIR:-}")" || exit $?
RUBRIC="$VP_ROOT/docs/review-rubric.md"
SPEC="$VP_ROOT/agents/pr-reviewer.md"
MODE="${1:-diff}"
ARG="${2:-}"

cd "$TARGET_DIR"

case "$MODE" in
  pr)
    DIFF="$(VP_ACTIVE_REPO="$TARGET_DIR" "$VP_ROOT/scripts/host.sh" pr-diff "$ARG" 2>/dev/null)" || {
      echo "FAIL: host.sh pr-diff $ARG" >&2; exit 2
    }
    LABEL="PR #$ARG" ;;
  range)
    DIFF="$(git diff "$ARG" 2>/dev/null)" || { echo "FAIL: git diff $ARG" >&2; exit 2; }
    LABEL="range $ARG" ;;
  diff|*)
    DIFF="$(git diff; git diff --staged)"
    LABEL="working tree" ;;
esac

if [ -z "${DIFF// }" ]; then
  echo "info: empty diff ($LABEL) — nothing to review."
  exit 0
fi

# Prefer local Claude Code (headless) if present; otherwise emit the assembled prompt for the
# caller (the Coordinator dispatches pr-reviewer via the Task tool).
PROMPT_FILE="$(mktemp)"
{
  echo "You are the pr-reviewer. Review ONLY the diff below against the rubric. Output findings as"
  echo "JSON: [{severity,category,location,failure_scenario,suggested_fix,verdict}], most-severe first."
  echo
  echo "===== ROLE SPEC ====="; cat "$SPEC" 2>/dev/null
  echo "===== RUBRIC ====="; cat "$RUBRIC" 2>/dev/null
  echo "===== DIFF ($LABEL) ====="; printf '%s\n' "$DIFF"
} > "$PROMPT_FILE"

if command -v claude >/dev/null 2>&1; then
  claude -p < "$PROMPT_FILE"
  rc=$?
  rm -f "$PROMPT_FILE"
  exit $rc
else
  echo "info: 'claude' CLI not found — assembled review prompt written to: $PROMPT_FILE" >&2
  echo "      (Coordinator should dispatch pr-reviewer via the Task tool on: $LABEL)"
  exit 0
fi
