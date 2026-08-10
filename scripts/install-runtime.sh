#!/usr/bin/env bash
# Install the complete bug-finder runtime into a target repository.
# Existing files are never overwritten unless --force is explicitly supplied.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/resolve-repo.sh"
TARGET="$(resolve_repo "${1:-}")" || exit $?
FORCE="${2:-}"

# src (this plugin's layout) : dst (target repo's .claude/ layout — the CI templates below expect
# their companion files there regardless of how the plugin itself is organised).
FILES=(
  "runtime-version:.claude/runtime-version"
  "agents/pr-reviewer.md:.claude/agents/pr-reviewer.md"
  "scripts/ci-guard.sh:.claude/scripts/ci-guard.sh"
  "scripts/ci-pr-meta-check.sh:.claude/scripts/ci-pr-meta-check.sh"
  "scripts/resolve-repo.sh:.claude/scripts/resolve-repo.sh"
  "scripts/host.sh:.claude/scripts/host.sh"
  "docs/review-rubric.md:docs/review-rubric.md"
)

# The CI template + its host.sh backend are host-specific — install whichever one the target
# actually uses (see docs/adr/0002-host-agnostic-issue-pr-adapter.md). GitLab CI has no template yet.
CI_HOST="$(VP_ACTIVE_REPO="$TARGET" "$ROOT/scripts/host.sh" detect)"
case "$CI_HOST" in
  github)
    FILES+=(".github/workflows/bug-finder.yml:.github/workflows/bug-finder.yml")
    FILES+=("scripts/host-github.sh:.claude/scripts/host-github.sh")
    ;;
  *)
    echo "skipped: CI template (no template for host '$CI_HOST' yet — everything else installs normally)"
    ;;
esac

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

# Baseline toolchain health — informational only, never fails the install. Surfaces
# pre-existing gate breakage (missing lint config, broken test toolchain, etc.) up
# front at bootstrap time, so the first /work-issue run isn't the first time anyone
# learns the gate doesn't run cleanly here.
echo ""
echo "-- baseline toolchain health (informational, does not affect install) --"
ALLOW_EMPTY_GATE=1 bash "$ROOT/scripts/gate.sh" "$TARGET" > /tmp/bugrabbit-baseline-gate.$$ 2>&1
GATE_RC=$?
if [ "$GATE_RC" -eq 0 ]; then
  echo "  gate.sh: clean baseline"
else
  echo "  gate.sh: pre-existing issues found (not caused by this install) — see below"
  grep -E '^(FAIL|warn):' /tmp/bugrabbit-baseline-gate.$$ || true
fi
rm -f /tmp/bugrabbit-baseline-gate.$$
