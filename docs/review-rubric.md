# Review rubric — what `pr-reviewer` checks

The keystone for review quality. `pr-reviewer` verifies a diff against this list and reports only
issues **caused by or exposed in the changed hunks** (plus code they directly affect). Every finding
must cite `file:line`, a **concrete failure scenario** (inputs/state → wrong output/crash), a
severity, and a verdict (`CONFIRMED` | `PLAUSIBLE`). Prefer fewer high-confidence findings over noise.

## Severity

| Severity | Meaning |
|---|---|
| critical | Data loss, security breach, crash on a normal path, corruption. |
| high | Wrong result on a realistic input; a broken existing caller (regression). |
| medium | Wrong result on an edge case; degraded behaviour; missing error handling. |
| low | Minor / cosmetic / style with a real (small) effect. |

## Categories

1. **Correctness**
   - off-by-one, boundary conditions, empty/`null`/`undefined`/`NaN` inputs
   - wrong operator / inverted condition / precedence
   - unhandled error paths, swallowed exceptions, ignored return values
   - async: unawaited promises, races, unhandled rejections, ordering assumptions
   - resource leaks (files/handles/sockets/timers not closed)
   - incorrect state mutation / shared-state aliasing

2. **Regression** (use codebase-memory `trace_path`)
   - a changed function's callers relying on removed/renamed/re-typed behaviour
   - changed defaults, signatures, return shapes, thrown errors
   - behaviour depended on elsewhere silently altered

3. **Security** (cite, never exploit)
   - injection (SQL/shell/template), unsafe `eval`/deserialization
   - unvalidated/unescaped external input; path traversal
   - secrets in code/logs/fixtures; tokens committed
   - authz/authn gaps, missing checks on a protected path
   - risky new dependency / unpinned action or image

4. **Efficiency** (only when the diff introduces it)
   - accidental O(n²) / repeated work on a hot path
   - needless re-computation, N+1 calls, unbounded growth

5. **Tests**
   - new/changed behaviour with no test
   - a test that does not actually assert the fixed behaviour

## Out of scope for a diff review

- Whole-repo audits, pre-existing issues untouched by the diff, pure style preference with no effect.
- Opening/merging PRs, editing code (review-only).

## Output shape

`[{severity, category, location (file:line), failure_scenario, suggested_fix, verdict}]`,
most-severe first; empty list when clean. Verdict `pass` (no critical/high) or `changes_required`.

## Labels (the classifier's visible form)

Severity/category aren't only recorded in `docs/findings.md` — on an actual PR (`/review-pr`, or
CI's `bug-finder.yml`), the Coordinator applies them as real host labels via `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh
pr-label`: `severity:<max>` (the highest severity across findings) plus one `category:<c>` per
distinct category present, using the exact lowercase names from the two tables above (e.g.
`severity:high`, `category:security`). `bug-triager` does the same for issues at triage time —
`severity:<sev>` only, via `host.sh issue-label` (issues have no category, that's a diff-review
concept). Best-effort: a host without label support (Bitbucket) prints a note and continues, never
blocks. Unknown label names are created automatically where the host supports it (GitHub, GitLab).
