#!/usr/bin/env bash
#
# ci-guard.sh — defensive validation helper. GitHub token permissions and runner isolation remain
# the actual security boundary; this script catches obvious protected-branch mistakes.
#
# Usage:
#   ci-guard.sh assert            # assert we are NOT on/targeting main/master; exit non-zero if so
#   ci-guard.sh check-cmd "<cmd>" # exit non-zero if <cmd> is a forbidden mutation
#
set -uo pipefail

PROTECTED_RE='^(main|master)$'

forbidden_cmd() {
  local c="$1"
  case "$c" in
    *"gh pr merge"*|*"gh pr create"*|*"git push --force"*|*"git push -f"*|\
    *"git push origin main"*|*"git push origin master"*|\
    *"git rebase"*|*"git commit --amend"*) return 0 ;;
    *) return 1 ;;
  esac
}

case "${1:-assert}" in
  assert)
    BR="${GITHUB_HEAD_REF:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"
    if echo "$BR" | grep -qE "$PROTECTED_RE"; then
      echo "CI-GUARD FAIL: refusing to run a mutating job on protected branch '$BR'." >&2
      exit 3
    fi
    echo "ci-guard: ok (branch '$BR' is not protected)"
    ;;
  check-cmd)
    shift
    if forbidden_cmd "$*"; then
      echo "CI-GUARD FAIL: forbidden command blocked: $*" >&2
      exit 3
    fi
    echo "ci-guard: ok (command allowed)"
    ;;
  *)
    echo "usage: ci-guard.sh {assert|check-cmd <cmd>}" >&2; exit 2 ;;
esac
