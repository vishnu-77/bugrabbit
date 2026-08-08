---
description: Read-only bug-finding review of a PR via pr-reviewer; records findings.
argument-hint: <pr-number>
---

Use the enclosing Git repository, or the `/set-repo` override. Review PR **#$ARGUMENTS** for bugs. Read-only — no code
changes, no merge.

1. Confirm the active repo + its host authed (`${CLAUDE_PLUGIN_ROOT}/scripts/host.sh auth-status`). Fetch the PR
   (`${CLAUDE_PLUGIN_ROOT}/scripts/host.sh pr-view $ARGUMENTS`, `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh pr-diff $ARGUMENTS`);
   if it does not exist, stop.
2. **Load** `${CLAUDE_PLUGIN_ROOT}/agents/pr-reviewer.md` by plugin-relative path; if absent, **REFUSE (fail-closed)**.
3. Spawn via the Task tool with **`model: sonnet`**, embedding:
   - the `pr-reviewer` spec **verbatim**,
   - the PR number + active repo absolute path (the agent runs `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh pr-diff $ARGUMENTS`),
   - `docs/review-rubric.md` (the checklist).
4. On return, record every finding as an `F-NNN` row in `docs/findings.md` (severity, `file:line`,
   scenario, source `pr-reviewer` + PR #).
5. **Optionally post comments** — only if the user asks. Findings may be posted as a PR comment with
   `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh pr-comment $ARGUMENTS --body-file <f>`. Never approve, never merge — no such
   op exists in the adapter on any host.
6. Print the findings table (most-severe first) and the verdict (`pass` / `changes_required`).
