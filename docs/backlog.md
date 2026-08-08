# Backlog — bug-fixing system

Source of truth for **open fix work**. One `FIX-NNN` row per repository-qualified issue.

**Dedup key = `owner/repo#issue`.** Never mint a second row for the same issue in the same repository.
`/triage-issue` and `/work-issue` check-before-write; `/status-check` detects `DUP-ROW`.

## Status legend

| Status | Meaning |
|---|---|
| `READY` | Triaged; fix-task written; not yet started. |
| `IN-PROGRESS` | `bug-fixer` is building the fix on a branch. |
| `IN-REVIEW` | Gate green; in `pr-reviewer` ∥ `qa-verifier` review. |
| `DONE` | Reviews passed, branch pushed. (Human opens the PR.) Archive later. |
| `PARTIAL` | A safe, bounded slice of the issue's full scope shipped (reviews passed, branch pushed); the remainder is deliberately deferred — e.g. it touches money/PII paths needing explicit human sign-off, or spans far more call sites than one fix should. The task body must name exactly what shipped and what's deferred, as its own follow-up. |
| `BLOCKED` | Not reproducible / cause unclear / upstream precondition unmet. |

Every row carries `created`/`updated` as UTC ISO-8601 (`date -u +%Y-%m-%dT%H:%M:%SZ`) — the audit
trail of when a task was triaged and when its status last changed. `created` is stamped once, at
first append; `updated` is re-stamped on every status transition (`/triage-issue`, `/assign`,
`/work-issue`, `/status-check`'s markdown-only fixes).

## Task table

| FIX-NNN | repository | issue # | title | severity | status | root cause (file:line) | branch | created (UTC) | updated (UTC) |
|---------|------------|---------|-------|----------|--------|------------------------|--------|---------------|---------------|
| — | — | — | (none yet) | — | — | — | — | — | — |

## Task bodies

<!-- One block per FIX-NNN, written from docs/templates/fix-task.md. Example shape:

### FIX-001 · acme/widgets#12 · null guard in scan parser
- **Repository:** acme/widgets
- **Severity:** high
- **Root cause:** app.js:214 — `parseResult()` dereferences `r.meta` when a scan returns no meta.
- **Repro:** `node server.js` then POST an empty scan → TypeError.
- **Blast radius (trace_path):** callers `handleStream()`, `renderReport()`.
- **Proposed fix:** guard `r.meta` at the cause site; default to `{}`.
- **Verify:** repro before (throws) → after (renders empty report); gate green.
- **Branch:** fix/12-null-guard   **Status:** READY
- **Created:** 2026-08-08T09:14:00Z   **Updated:** 2026-08-08T09:14:00Z
- **Label:** severity:high (applied to the issue via `host.sh issue-label`)
-->
