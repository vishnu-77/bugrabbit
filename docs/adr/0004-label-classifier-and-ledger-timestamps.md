# 0004. Host-label classifier + ledger timestamps

**Status:** Accepted
**Date:** 2026-08-08

## Context

`bug-triager` and `pr-reviewer` already classify everything they find — severity on every triage,
severity + category on every review finding — but that classification lived only inside BugRabbit's
own markdown ledgers (`docs/backlog.md`, `docs/findings.md`). It was invisible from the tracker's own
UI: nothing let you filter GitHub's issue list by severity, or see at a glance what kind of problem a
PR's findings were, without opening BugRabbit's files. Separately, `docs/backlog.md` and
`docs/findings.md` recorded *what* was found and its *current* status, but never *when* — no field
answered "how long has this finding sat open" or "when did this task actually start."

Both gaps were raised in the same conversation, framed as an audit-trail question: what does
BugRabbit record, and what's missing from it.

## Decision

**Classifier → real host labels, not just ledger columns.**
- Two new ops on the existing `host.sh` contract (extending [0002](0002-host-agnostic-issue-pr-adapter.md)'s
  op set): `issue-label <#> --label L...` and `pr-label <#> --label L...`.
- Taxonomy: `severity:{critical|high|medium|low}` (the exact lowercase names already in
  `docs/review-rubric.md`), applied to **issues** at triage time (`bug-triager`, severity only — an
  issue has no diff to categorize) and to **PRs** on review (`pr-reviewer`: `severity:<max>` across
  findings plus one `category:<c>` per distinct category present).
- **Best-effort, host-dependent, never blocking.** GitHub: `gh api` on the issue-labels endpoint,
  which auto-creates unknown label names (verified live in this session against a real repo before
  choosing this over `gh issue edit --add-label`, which requires the label to pre-exist). GitLab:
  `add_labels` on the issue/MR PUT, which GitLab auto-creates too. Bitbucket: no-op with a printed
  note — Bitbucket has no label concept for issues or PRs, same shape as the existing `--label`
  handling on `issue-create`/`issue-list` from 0002.
- CI (`bug-finder.yml`, `bitbucket-pipelines.yml`) does the same thing automatically after posting
  the review comment: best-effort `grep` over the review's own markdown table for the rubric's known
  severity/category tokens, since the CI job has no structured agent Return to read, only the
  rendered table text.

**Ledgers → `created`/`updated` (`docs/backlog.md`) and `raised`/`updated`
(`docs/findings.md`), UTC ISO-8601.**
- Stamped once at first append, re-stamped on every status transition (`/triage-issue`, `/assign`,
  `/work-issue`'s four steps, `/findings close`).
- Carried through, not dropped, when `/archive-task` moves a settled row to
  `docs/backlog-archive.md` — the archive keeps the full `created → updated → archived` history.
- `/status-check`'s `STALE-DONE`/`STALE-PARTIAL` detection now reports *how* stale using `updated`,
  not just that a mismatch exists.

**Deliberately not done:** `docs/issue-log.md` already had a `first_seen` column and wasn't touched —
this ADR only closes the gap that existed in the other two ledgers. No new command was added; this is
existing commands doing one more thing each, not a new surface.

## Consequences

- **+** Severity/category are now visible and filterable in the tracker's native UI, not just in
  BugRabbit's own files — closes the "classification exists but is invisible outside the plugin" gap.
- **+** Every ledger row now answers "when," not just "what" and "current status" — a finding or task
  sitting stale is now directly measurable instead of inferred from git history alone.
- **+** The label taxonomy is a single source of truth (`docs/review-rubric.md`'s existing severity/
  category tables) — no separate label vocabulary to keep in sync.
- **−** CI's label step reads the review's markdown table by **column position** (actual generated
  order: `severity | category | location | scenario | fix | verdict` — six columns, no leading `#`),
  not a structured field — it can miss a finding whose table row is formatted unexpectedly. It fails
  soft (no labels applied, never fails the job) rather than fabricating a wrong label, but it's a
  heuristic, not a guarantee.
  **Caught during verification, fixed before merge:** the first version grepped whole row *text*
  instead of the specific column, and false-positived `category:regression` on a table whose only
  real categories were `correctness`/`tests` — the word "regression" appeared inside a *suggested-fix*
  sentence ("add a regression test"), not the category column. Verified clean against both a findings
  table and an empty/clean-review table before landing.
  **Second bug, caught in a later follow-up check (not this same session):** the fix above still
  assumed a *seven*-column table with a leading `#` (`$3`/`$4` for severity/category), matching
  neither the CI prompt's instructed 6-column shape nor the rubric's documented output shape — it was
  verified only against a hand-built sample table that happened to include a `#` column, not against
  actual model output. Net effect: `SEV_COL`/`CAT_COL` silently read the *category*/*location* values
  instead of *severity*/*category*, so the classifier applied **zero labels on every real review**,
  always — while still reporting nothing wrong, since "no labels" is also the correct output for a
  clean review. Confirmed by generating a real review table from the exact CI prompt and running the
  actual extraction code against it before and after the fix (`$2`/`$3`, not `$3`/`$4`). Both
  `bug-finder.yml` and `bitbucket-pipelines.yml` had the identical bug; both fixed together.
- **−** Neither the labeling nor the timestamp-stamping was exercised against a live PR/issue in this
  change — `host-github.sh`'s `gh api` auto-create behavior was verified live earlier in this session
  via a different path (the MCP GitHub tools, not `gh` itself), not via `issue-label`/`pr-label`
  specifically. Treat as unverified until a real `/triage-issue` → `/review-pr` pass confirms the
  labels land and auto-create as expected.
- **−** GitLab's `issue-label`/`pr-label` were written to the same contract as `host-gitlab.sh`'s
  other ops but, like the rest of that backend (0003), have no live GitLab project to verify against.
