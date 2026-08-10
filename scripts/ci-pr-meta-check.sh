#!/usr/bin/env bash
#
# ci-pr-meta-check.sh — PR-meta gate for the bug-fixing system.
#
# Validates the git conventions in CLAUDE.md §3 (turns the prose rule into an enforced gate):
#   1. Branch name           — <branch-type>/<issue#>-<desc>   e.g. fix/12-null-guard
#   2. Commit subjects       — #<issue> <type>(<scope>)?: <summary>   on the PR range
#   3. PR title (if provided) — same shape as a commit subject (or "#<issue> <desc>")
#   4. NO Co-Authored-By: / Signed-off-by: trailers in any commit (hard rule).
#
# branch-type ∈ {fix|bugfix|chore|test|refactor|docs|perf}
# commit type ∈ {fix|test|refactor|docs|chore|perf|sec}
#
# Inputs (auto-detected; override for local smoke tests):
#   Branch:  GITHUB_HEAD_REF | CI_COMMIT_REF_NAME (GitLab) | current git branch
#   Base:    GITHUB_BASE_REF | CI_MERGE_REQUEST_TARGET_BRANCH_NAME (GitLab) | "main"
#   PR title (optional): PR_TITLE
#
# Runs locally against the current branch's commits vs base, and in CI.
# Prints all violations; exits 0 clean / 1 violation / 2 IO error.
set -uo pipefail

err()  { echo "FAIL: $*" >&2; FAIL=1; }
note() { echo "info: $*"; }

TYPES='fix|test|refactor|docs|chore|perf|sec'
BRANCH_TYPES='fix|bugfix|chore|test|refactor|docs|perf'

BRANCH="${GITHUB_HEAD_REF:-${CI_COMMIT_REF_NAME:-}}"
[ -z "$BRANCH" ] && BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
BASE="${GITHUB_BASE_REF:-${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-main}}"
[ -z "$BRANCH" ] && { echo "error: could not determine branch (set GITHUB_HEAD_REF or run in a git repo)" >&2; exit 2; }

note "branch: ${BRANCH}"; note "base: ${BASE}"
FAIL=0

# 1. Branch name -----------------------------------------------------------
if ! echo "$BRANCH" | grep -qE "^(${BRANCH_TYPES})/[0-9]+-[a-z0-9._-]+$"; then
  # allow the default branch itself to pass (nothing to check)
  if echo "$BRANCH" | grep -qE '^(main|master|HEAD)$'; then
    note "on ${BRANCH} — skipping branch-name check"
  else
    err "branch '$BRANCH' must match <${BRANCH_TYPES}>/<issue#>-<desc> (e.g. fix/12-null-guard)"
  fi
fi

# Resolve the commit range vs base.
RANGE=""
if git rev-parse --verify -q "origin/$BASE" >/dev/null 2>&1; then
  RANGE="origin/$BASE..HEAD"
elif git rev-parse --verify -q "$BASE" >/dev/null 2>&1; then
  RANGE="$BASE..HEAD"
fi

# 2 + 4. Commit subjects + trailer ban ------------------------------------
if [ -n "$RANGE" ]; then
  SUBJECTS="$(git log --format='%s' "$RANGE" 2>/dev/null || true)"
  if [ -z "$SUBJECTS" ]; then
    note "no commits in range $RANGE (nothing to check)"
  else
    while IFS= read -r s; do
      [ -z "$s" ] && continue
      if ! echo "$s" | grep -qE "^#[0-9]+ (${TYPES})(\([a-z0-9._/-]+\))?: .+"; then
        err "commit subject not conformant: '$s'  (want: '#<issue> <type>(<scope>): <summary>')"
      fi
    done <<< "$SUBJECTS"
  fi

  # Trailer ban across the full commit bodies in range.
  if git log --format='%B' "$RANGE" 2>/dev/null | grep -qiE '^(Co-Authored-By|Signed-off-by):'; then
    err "found Co-Authored-By:/Signed-off-by: trailer in the PR range — remove it (hard rule §3)"
  fi
else
  note "base '$BASE' not resolvable — skipping commit checks (local shallow checkout?)"
fi

# 3. PR title (optional) ---------------------------------------------------
if [ -n "${PR_TITLE:-}" ]; then
  if ! echo "$PR_TITLE" | grep -qE "^#[0-9]+ ((${TYPES})(\([a-z0-9._/-]+\))?: .+|.+)"; then
    err "PR title not conformant: '$PR_TITLE'  (want: '#<issue> <desc>')"
  fi
fi

if [ "$FAIL" -ne 0 ]; then
  echo "== pr-meta: FAIL ==" >&2
  exit 1
fi
echo "== pr-meta: PASS =="
