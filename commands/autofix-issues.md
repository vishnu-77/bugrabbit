---
description: Batch — triage and fix ALL eligible open issues, then produce one comprehensive report.
argument-hint: "[--label auto-fix] [--severity high] [--limit N] [--dry-run]"
---

Use the enclosing Git repository, or the `/set-repo` override; the active repo's host must be
authenticated (`${CLAUDE_PLUGIN_ROOT}/scripts/host.sh auth-status` — `gh` for GitHub, `BUGRABBIT_GL_TOKEN` for GitLab).
Run the fix pipeline across **all eligible open issues** and return a single well-formatted summary.
Idempotent — safe to re-run.

**Selection + dedup:**
1. Refresh the seen set: run `${CLAUDE_PLUGIN_ROOT}/scripts/poll-issues.sh` (records new issues `UNTRIAGED`).
2. Build the work set from open issues, filtered by `--label` (default `auto-fix`), `--severity`,
   `--limit`. **Skip** any issue that already has a `FIX-NNN` row with status `DONE` or `PARTIAL`, an
   open PR from a `fix/<#>-*` branch, or an issue-log status `DONE`/`SKIPPED` — never redo settled
   work. A `PARTIAL` row means a bounded slice already shipped; its documented remainder is separate
   follow-up work, not something this pass should pick back up automatically.
3. If `--dry-run`, print the work set + why each was included/skipped and stop (no mutations).

**Execution (bounded, sequential per issue to keep a clean branch boundary):**
4. For each issue in the work set, run the `/work-issue <#>` flow (triage → fix → review ∥ qa →
   push). One branch per issue; never batch fixes. Stop an individual issue on `BLOCKED`/
   `GATE_LOOP_EXHAUSTED` and continue to the next (record the reason). Respect `--limit`.
5. Update `docs/issue-log.md` and `docs/backlog.md` statuses as you go (idempotent).

**Comprehensive report (always print at the end):**
```
## autofix-issues — <repo> — <date>
Processed: N  |  Fixed(branch pushed): X  |  Blocked: Y  |  Skipped(already done): Z

| issue | severity | FIX-NNN | outcome            | branch                 | findings | notes |
|-------|----------|---------|--------------------|------------------------|----------|-------|
| #12   | high     | FIX-003 | FIXED (push, no PR)| fix/12-null-guard      | 1 high   | ...   |
| #14   | medium   | FIX-004 | BLOCKED            | —                      | —        | not reproducible |
...

Open findings (critical/high): <from docs/findings.md>
Next actions: open PRs for pushed branches: <list>  ·  re-triage blocked: <list>
```
Never opens or merges PRs. Every pushed branch is left for the human to PR.
