#!/usr/bin/env bash
# Resolve the repository operated on by bug-fixer.
# Priority: explicit argument, VP_ACTIVE_REPO override, enclosing Git repository.

resolve_repo() {
  local explicit="${1:-}"
  local candidate="${explicit:-${VP_ACTIVE_REPO:-}}"

  if [ -n "$candidate" ]; then
    git -C "$candidate" rev-parse --show-toplevel 2>/dev/null || {
      echo "FAIL: not inside a git repository: $candidate" >&2
      return 2
    }
    return 0
  fi

  git rev-parse --show-toplevel 2>/dev/null || {
    echo "FAIL: no repository found; run from a Git repository or pass a path" >&2
    return 2
  }
}
