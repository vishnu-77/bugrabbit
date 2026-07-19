# Backlog — bug-fixing system

Source of truth for **open fix work**. One `FIX-NNN` row per repository-qualified GitHub issue.

**Dedup key = `owner/repo#issue`.** Never mint a second row for the same issue in the same repository.
`/triage-issue` and `/work-issue` check-before-write; `/status-check` detects `DUP-ROW`.

## Status legend

| Status | Meaning |
|---|---|
| `READY` | Triaged; fix-task written; not yet started. |
| `IN-PROGRESS` | `bug-fixer` is building the fix on a branch. |
| `IN-REVIEW` | Gate green; in `pr-reviewer` ∥ `qa-verifier` review. |
| `DONE` | Reviews passed, branch pushed. (Human opens the PR.) Archive later. |
| `BLOCKED` | Not reproducible / cause unclear / upstream precondition unmet. |

## Task table

| FIX-NNN | repository | issue # | title | severity | status | root cause (file:line) | branch |
|---------|------------|---------|-------|----------|--------|------------------------|--------|
| — | — | — | (none yet) | — | — | — | — |

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
-->
