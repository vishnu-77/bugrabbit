#!/usr/bin/env bash
#
# host.sh — dispatcher for issue/PR operations against the active repo's host (GitHub or GitLab;
# see docs/adr/0002-host-agnostic-issue-pr-adapter.md and
# docs/adr/0005-drop-bitbucket-support.md). Detects the host from the origin remote (override with
# VP_HOST=github|gitlab for Enterprise/self-hosted domains that don't string-match) and forwards to
# scripts/host-<host>.sh. Acts on $VP_ACTIVE_REPO / the enclosing git repo — same resolution as
# every other BugRabbit script (see resolve-repo.sh).
#
# No op here ever opens or merges a PR — that capability simply doesn't exist in this contract,
# which is what keeps "agents never open/merge PRs" true across hosts without per-host deny-guards.
#
# Usage: host.sh <op> [op-args...]
#   detect                 — print the detected host id (github | gitlab | unknown)
#   remote-slug            — print owner/repo (or namespace/project) parsed from the origin remote
#   auth-status            — exit 0 + "ok" if the host CLI/API is usable, else FAIL + exit 2
#   issue-view <#>
#   issue-list [--state open|all] [--label L] [--search Q]   — prints TSV: number\tstate\ttitle
#   issue-state <#>        — prints normalized "open" or "closed"
#   issue-create --title T [--body B] [--label L]
#   issue-label <#> --label L [--label L2 ...]   — add labels to an existing issue (auto-creates the
#                                                   label where the host supports it)
#   pr-diff <#>
#   pr-view <#>
#   pr-list [--state open]  — prints TSV: number\tstate\ttitle\tbranch
#   pr-comment <#> --body-file F
#   pr-label <#> --label L [--label L2 ...]      — add labels to an existing PR/MR (same caveats as
#                                                   issue-label)
#
set -uo pipefail

VP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$VP_ROOT/scripts/resolve-repo.sh"
TARGET="$(resolve_repo "")" || exit $?

remote_slug() {
  git -C "$TARGET" remote get-url origin 2>/dev/null | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##'
}

detect_host() {
  if [ -n "${VP_HOST:-}" ]; then echo "$VP_HOST"; return; fi
  local url; url="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
  case "$url" in
    *github.com*) echo github ;;
    *gitlab.com*) echo gitlab ;;
    *) echo unknown ;;
  esac
}

OP="${1:-}"; shift || true
[ -n "$OP" ] || { echo "usage: host.sh <op> [op-args...]" >&2; exit 2; }

case "$OP" in
  detect) detect_host; exit 0 ;;
  remote-slug)
    slug="$(remote_slug)"
    [ -n "$slug" ] || { echo "FAIL: could not derive owner/repo from origin remote" >&2; exit 2; }
    echo "$slug"; exit 0 ;;
esac

HOST="$(detect_host)"
BACKEND="$VP_ROOT/scripts/host-$HOST.sh"
[ -f "$BACKEND" ] || {
  echo "FAIL: unsupported host '$HOST' for op '$OP' (set VP_HOST=github|gitlab to override detection)" >&2
  exit 2
}
SLUG="$(remote_slug)"
[ -n "$SLUG" ] || { echo "FAIL: could not derive owner/repo from origin remote" >&2; exit 2; }

exec bash "$BACKEND" "$OP" "$SLUG" "$TARGET" "$@"
