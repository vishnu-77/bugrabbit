---
description: Work one issue end-to-end — triage, fix on a branch, review + QA, push. Idempotent. Never opens a PR.
argument-hint: <issue-number>
---

Use the enclosing Git repository, or the `/set-repo` override. Work issue **#$ARGUMENTS** end-to-end. The agent pushes
a branch; the **human opens the PR** (agents never open/merge PRs).

**Idempotency + dedup (check FIRST — never duplicate work):**
- Derive `owner/repo` from the active repository's `origin`; use `owner/repo#$ARGUMENTS` for every
  ledger lookup. If a matching `FIX-NNN` row exists in `docs/backlog.md`:
  - status `DONE` or `PARTIAL` → report it (branch + commit, and for `PARTIAL` the documented
    deferred remainder) and stop unless the user forces a redo.
  - status `IN-PROGRESS`/`IN-REVIEW` → resume that row; do not mint a new one.
- If a branch `fix/$ARGUMENTS-*` already exists (local or remote, `git branch -a`), **reuse it** —
  never create a second branch for the same issue.
- Mark the issue-log row (`docs/issue-log.md`) `WORKING`.

1. **Triage (if no row).** Dispatch `bug-triager` (spec verbatim + issue # + active repo path +
   `docs/fix-playbook.md`, `model: sonnet`). If `BLOCKED`, surface the blocker and stop. Else append
   one `FIX-NNN` row (keyed by `owner/repo#issue`, `created`/`updated` both stamped `date -u
   +%Y-%m-%dT%H:%M:%SZ`) and label the issue (`${CLAUDE_PLUGIN_ROOT}/scripts/host.sh issue-label $ARGUMENTS --label
   severity:<sev>` — best-effort, never blocks on a host that can't label).
2. **Fix.** `/assign <FIX-NNN> bug-fixer`. Mark row `IN-PROGRESS`, stamp `updated`. The fixer
   reuses/creates `fix/$ARGUMENTS-<slug>`, makes the smallest root-cause change, drives `gate.sh`
   green, commits `#$ARGUMENTS fix(<scope>): <summary>`, pushes the branch. Handle `NEEDS_FIX`/
   `BLOCKED`/`GATE_LOOP_EXHAUSTED`. If the Return includes `memory_insight`, append a row to
   `docs/bugrabbit-memory.md`.
3. **Review + QA (parallel, one message)** after gate green: dispatch `pr-reviewer` + `qa-verifier`
   on the branch. Mark row `IN-REVIEW`, stamp `updated`. Record `pr-reviewer` findings as `F-NNN`
   rows (`raised`/`updated` both stamped now). On `changes_required`, re-assign `bug-fixer` with the
   findings (bounded loop, cap 3).
4. **Close.** `git status` clean, branch pushed. Mark row `DONE`, stamp `updated`, issue-log `DONE`.
   Print the branch + commit set and tell the user to open the PR themselves. Do not merge.

Note: `pr-reviewer` runs here against a **branch**, not yet an open PR (the human opens it later), so
there's no PR to label at this step — the severity label from step 1 is the only labeling that
happens inside `/work-issue`. A PR-level `severity`/`category` label set is applied later, when the
human's opened PR gets reviewed via `/review-pr` or CI.
