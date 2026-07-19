---
description: Deep drift + dedup audit — reconcile GitHub issues/PRs ↔ backlog (FIX-NNN) ↔ branches ↔ issue-log. Read-first.
---

Use the enclosing Git repository, or the `/set-repo` override. Deep consistency audit across all state. **Read-first**; the
only writes are markdown corrections to `docs/backlog.md` / `docs/issue-log.md` (never code, never
Jira, never GitHub state).

Reconcile these four sources and report every mismatch:

1. **GitHub issues** (`gh issue list --state all`) — the source of truth for what exists.
2. **`docs/issue-log.md`** — the cron "seen" set.
3. **`docs/backlog.md`** — `FIX-NNN` rows (dedup key = `owner/repo#issue`). Only reconcile rows
   belonging to the active repository.
4. **Branches** (`git branch -a`) + **open PRs** (`gh pr list`).

Detect and label:
- **DUP-ROW** — two `FIX-NNN` rows cite the same repository-qualified issue (dedup violation). Recommend keeping the
  oldest, superseding the rest.
- **DUP-BRANCH** — more than one `fix/<#>-*` branch for one issue.
- **ORPHAN-ROW** — a `FIX-NNN` row whose issue is `closed`/deleted on GitHub → mark for archive.
- **STALE-DONE** — a row `DONE` but its issue is still open with no merged PR → flag for recheck.
- **UNTRACKED** — an open issue with no issue-log row (cron missed it) → append `UNTRIAGED`.
- **UNWORKED** — issue-log `UNTRIAGED`/`TRIAGED` older than N days with no branch → surface as backlog.
- **DRIFT-STATUS** — backlog status disagrees with reality (e.g. `IN-PROGRESS` but branch pushed +
  reviews done).

Output: a table of findings per category + a suggested reconciliation for each. Apply **only** the
markdown fixes the user approves. Run this at the end of `/autofix-issues` and after cron polls.
