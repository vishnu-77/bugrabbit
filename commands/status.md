---
description: Backlog + open GitHub issues/PRs summary for the active repo.
---

Read-only summary. Uses the enclosing Git repository or the `/set-repo` override.

1. **Backlog.** Run `${CLAUDE_PLUGIN_ROOT}/scripts/repo-status.sh` (or read `docs/backlog.md`): count `FIX-NNN`
   rows by status (`READY`, `IN-PROGRESS`, `IN-REVIEW`, `DONE`, `PARTIAL`, `BLOCKED`) and list open
   ones with their issue #, severity, and branch.
2. **Findings.** Count open `F-NNN` rows in `docs/findings.md` by severity; list any `critical`/`high`
   still `open`.
3. **GitHub (if `gh` authed).** For the active repo: open issues labelled `auto-fix`
   (`gh issue list --label auto-fix --state open`) and open PRs (`gh pr list --state open`).
4. Print a compact table and name the next unblocked action (e.g. "triage issue #12" or
   "fix FIX-003"). No mutations.
