#!/usr/bin/env bash
#
# gate.sh — language-agnostic local quality gate for the bug-fixing system.
#
# Runs, in order, whatever the TARGET repo supports:
#   (0) secrets     — HARD if gitleaks is installed and finds a leak (runs first, fail-fast)
#   (a) lint        — HARD if a linter is configured
#   (b) typecheck   — HARD if a typechecker is configured
#   (c) test        — HARD if a test script/target exists
#   (d) build       — HARD if a build script/target exists
#
# Toolchain is auto-detected from the target tree (Node/npm, Python, Go, Make, generic).
# A step is HARD-fail when the tool exists and runs; it is WARN-and-SKIPPED when the tool is
# absent or no relevant config is present. If NOTHING runs, the gate is INCONCLUSIVE and exits 2;
# set ALLOW_EMPTY_GATE=1 only for exploratory local work that must not be marked verified.
#
# Usage: gate.sh [TARGET_DIR]
#   TARGET_DIR (optional) — the repo to gate. Default: $VP_ACTIVE_REPO, else the current dir.
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resolve-repo.sh
source "$SCRIPT_DIR/resolve-repo.sh"
TARGET="$(resolve_repo "${1:-}")" || exit $?
if [ ! -d "$TARGET" ]; then
  echo "FAIL: target dir not found: $TARGET" >&2
  exit 2
fi
cd "$TARGET"

FAIL=0
RAN=0
have() { command -v "$1" >/dev/null 2>&1; }
hard() { echo "FAIL: $*" >&2; FAIL=1; }
warn() { echo "warn: $*" >&2; }
ok()   { echo "ok:   $*"; }
run()  { # run <label> <cmd...> ; HARD on non-zero
  local label="$1"; shift
  echo "-- $label: $*"
  if "$@"; then ok "$label"; RAN=1; else hard "$label ($*)"; RAN=1; fi
}
# Does package.json define script $1 ?
npm_has() { [ -f package.json ] && node -e "process.exit(((require('./package.json').scripts)||{})['$1']?0:1)" 2>/dev/null; }

echo "== gate.sh @ $TARGET =="

# ---- Secrets (gitleaks) ---------------------------------------------------
# Language-agnostic, runs first: a leaked key is worse than a lint failure. HARD
# fail on any finding; WARN-and-skip if gitleaks isn't installed (same pattern as
# every other tool below). Deliberately NOT counted toward RAN — this is an
# additional gate, not a substitute for the toolchain verification RAN tracks.
# --redact keeps the actual secret value out of gate output/logs (rule: no
# secrets in logs — CLAUDE.md #8).
if have gitleaks; then
  if gitleaks detect --source . --no-git --redact -v; then
    ok "gitleaks (no secrets found)"
  else
    hard "gitleaks (potential secret(s) found — see output above)"
  fi
else
  warn "gitleaks not installed — secret scan skipped (https://github.com/gitleaks/gitleaks)"
fi

# ---- Node / npm ----------------------------------------------------------
if [ -f package.json ]; then
  if have npm; then
    npm_has lint       && run "lint"       npm run --silent lint
    npm_has typecheck  && run "typecheck"  npm run --silent typecheck
    if npm_has test; then
      run "test" npm test --silent
    else
      warn "node: no 'test' script in package.json (skipped)"
    fi
    npm_has build      && run "build"      npm run --silent build

    # Monorepo fallback: the root package.json declares workspaces (npm/yarn
    # `workspaces` field, or a pnpm-workspace.yaml) but has no runnable scripts
    # of its own — common in this shape of repo. Rather than go INCONCLUSIVE,
    # gate every workspace that has its own scripts. No subshells: cd there and
    # back so `run`'s FAIL/RAN mutations propagate to this process, not a child.
    if [ "$RAN" -eq 0 ]; then
      IS_WORKSPACE_ROOT=0
      node -e "process.exit((require('./package.json').workspaces)?0:1)" 2>/dev/null && IS_WORKSPACE_ROOT=1
      [ -f pnpm-workspace.yaml ] && IS_WORKSPACE_ROOT=1
      if [ "$IS_WORKSPACE_ROOT" = "1" ]; then
        echo "-- monorepo root has no runnable scripts; gating individual workspaces --"
        ROOT_DIR="$(pwd)"
        while IFS= read -r ws_pkg; do
          ws_dir="$(dirname "$ws_pkg")"
          [ "$ws_dir" = "." ] && continue
          echo "-- workspace: $ws_dir --"
          cd "$ROOT_DIR/$ws_dir"
          npm_has lint       && run "lint ($ws_dir)"       npm run --silent lint
          npm_has typecheck  && run "typecheck ($ws_dir)"  npm run --silent typecheck
          npm_has test       && run "test ($ws_dir)"       npm test --silent
          npm_has build      && run "build ($ws_dir)"      npm run --silent build
          cd "$ROOT_DIR"
        done < <(find . -maxdepth 3 -name package.json -not -path '*/node_modules/*' ! -path './package.json')
      fi
    fi
  else
    hard "package.json present but npm not installed"
  fi
fi

# ---- Python --------------------------------------------------------------
if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f requirements.txt ] || ls ./*.py >/dev/null 2>&1; then
  have ruff        && run "ruff"    ruff check .
  have mypy        && [ -f mypy.ini -o -f pyproject.toml ] && run "mypy" mypy .
  if have pytest; then run "pytest" pytest -q; else hard "python detected but pytest not installed"; fi
fi

# ---- Go ------------------------------------------------------------------
if [ -f go.mod ]; then
  if have go; then
    run "go vet"   go vet ./...
    run "go test"  go test ./...
    run "go build" go build ./...
  else
    hard "go.mod present but go not installed"
  fi
fi

# ---- Makefile fallback ---------------------------------------------------
if [ "$RAN" -eq 0 ] && [ -f Makefile ] && have make; then
  grep -qE '^test:' Makefile && run "make test" make test
fi

if [ "$FAIL" -ne 0 ]; then
  echo "== gate: FAIL =="
  exit 1
fi

if [ "$RAN" -eq 0 ]; then
  warn "no recognised toolchain (node/python/go/make) with runnable checks — verification is inconclusive."
  echo "== gate: INCONCLUSIVE (nothing ran) =="
  [ "${ALLOW_EMPTY_GATE:-0}" = "1" ] && exit 0
  exit 2
fi

echo "== gate: PASS =="
