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
   scenario, source `pr-reviewer` + PR #, `raised`/`updated` both stamped `date -u
   +%Y-%m-%dT%H:%M:%SZ`). If the Return includes `memory_insight`, append a row to
   `docs/bugrabbit-memory.md` too. Findings are surfaced here in chat and in the ledger — not posted
   anywhere else unless step 6 explicitly does so.
5. **Label the PR** (best-effort, never blocks): if findings is non-empty, `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh
   pr-label $ARGUMENTS --label severity:<max>` (the highest severity among findings) plus one `--label
   category:<c>` per distinct category present. Empty findings → no labels applied.
6. **Optionally post comments** — only if the user asks. Findings may be posted as a PR comment with
   `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh pr-comment $ARGUMENTS --body-file <f>`. Never approve, never merge — no such
   op exists in the adapter on any host.
7. Print the findings table (most-severe first) and the verdict (`pass` / `changes_required`).
