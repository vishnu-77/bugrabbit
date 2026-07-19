#!/usr/bin/env bash
# Install the complete bug-finder runtime into a target repository.
# Existing files are never overwritten unless --force is explicitly supplied.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/resolve-repo.sh"
TARGET="$(resolve_repo "${1:-}")" || exit $?
FORCE="${2:-}"

# src (this plugin's layout) : dst (target repo's .claude/ layout — bug-finder.yml expects its
# companion files there regardless of how the plugin itself is organised).
FILES=(
  "runtime-version:.claude/runtime-version"
  ".github/workflows/bug-finder.yml:.github/workflows/bug-finder.yml"
  "agents/pr-reviewer.md:.claude/agents/pr-reviewer.md"
  "scripts/ci-guard.sh:.claude/scripts/ci-guard.sh"
  "scripts/ci-pr-meta-check.sh:.claude/scripts/ci-pr-meta-check.sh"
  "docs/review-rubric.md:docs/review-rubric.md"
)

installed=0
unchanged=0
conflicts=0
for pair in "${FILES[@]}"; do
  rel="${pair%%:*}"
  dst_rel="${pair#*:}"
  src="$ROOT/$rel"
  dst="$TARGET/$dst_rel"
  [ -f "$src" ] || { echo "FAIL: runtime source missing: $rel" >&2; exit 2; }
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      echo "unchanged: $dst_rel"
      unchanged=$((unchanged + 1))
    elif [ "$FORCE" = "--force" ]; then
      cp "$src" "$dst"
      echo "updated:   $dst_rel"
      installed=$((installed + 1))
    else
      echo "conflict:  $dst_rel (rerun with --force after reviewing the diff)" >&2
      conflicts=$((conflicts + 1))
    fi
  else
    cp "$src" "$dst"
    echo "installed: $dst_rel"
    installed=$((installed + 1))
  fi
done

echo "runtime: installed=$installed unchanged=$unchanged conflicts=$conflicts"
[ "$conflicts" -eq 0 ] || exit 1
