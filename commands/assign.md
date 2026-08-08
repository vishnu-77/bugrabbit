---
description: Hand one backlog task to a Sonnet sub-agent via the Task tool (spec + task embedded, model pinned).
argument-hint: <FIX-NNN> <bug-triager|bug-fixer|pr-reviewer|qa-verifier>
---

Use the enclosing Git repository, or the `/set-repo` override. Assign task **$ARGUMENTS**. Single assignment only — the full
pipeline is `/fix-issue`.

1. Resolve the task ID (`FIX-NNN`) + target agent. The row must exist in `docs/backlog.md` and not be
   `DONE` or `PARTIAL` (a `PARTIAL` row's shipped slice is finished; its deferred remainder needs a
   new `FIX-NNN` row of its own, not reassignment of the old one). If exactly one open row and no
   agent given, auto-pick `bug-fixer` and **announce** the inference before proceeding.
2. **Load the agent by plugin-relative path** `${CLAUDE_PLUGIN_ROOT}/agents/<agent>.md` where `<agent>` ∈
   {`bug-triager`, `bug-fixer`, `pr-reviewer`, `qa-verifier`}. Confirm the file exists — if absent,
   **REFUSE (fail-closed)**; never dispatch a bare guessed name, never `~/.claude/agents/`.
3. Spawn via the Task tool with **`model: sonnet`**, embedding (the harness does NOT auto-load
   `${CLAUDE_PLUGIN_ROOT}/agents/*`):
   - the agent's spec from `${CLAUDE_PLUGIN_ROOT}/agents/<agent>.md` **verbatim**,
   - the full `fix-task` from the `FIX-NNN` row + the tracker issue number,
   - the **active repo absolute path**,
   - the relevant reference doc (`bug-triager`/`bug-fixer` → `docs/fix-playbook.md`;
     `pr-reviewer` → `docs/review-rubric.md`).
4. Mark the row `IN-PROGRESS` (`bug-triager`/`bug-fixer`) or `IN-REVIEW` (`pr-reviewer`/
   `qa-verifier`).
5. On return, triage the structured `STATUS:` result: `NEEDS_FIX` → re-assign `bug-fixer` with the
   findings; record review findings in `docs/findings.md`. Agents never open/merge PRs — the human
   does.
