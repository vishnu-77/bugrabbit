---
description: Read-only triage of one issue via bug-triager; appends a FIX-NNN backlog row.
argument-hint: <issue-number>
---

Use the enclosing Git repository, or the `/set-repo` override. Triage issue **#$ARGUMENTS**. Read-only — no code
changes, no branch.

1. Confirm the active repo is set and its host is authed (`${CLAUDE_PLUGIN_ROOT}/scripts/host.sh auth-status`).
   Fetch the issue (`${CLAUDE_PLUGIN_ROOT}/scripts/host.sh issue-view $ARGUMENTS`); if it does not exist, stop.
2. **Load the agent by plugin-relative path** `${CLAUDE_PLUGIN_ROOT}/agents/bug-triager.md`. If absent, **REFUSE
   (fail-closed)** — never dispatch a bare guessed name, never `~/.claude/agents/`.
3. Spawn via the Task tool with **`model: sonnet`**, embedding (the harness does NOT auto-load
   `${CLAUDE_PLUGIN_ROOT}/agents/*`):
   - the `bug-triager` spec **verbatim**,
   - the issue number + active repo absolute path,
   - `docs/fix-playbook.md` (root-cause methodology).
4. On return, if `STATUS: DONE`, append a `FIX-NNN` row to `docs/backlog.md` (repository, issue #,
   title, severity, root-cause `file:line`, status `READY`) using `docs/templates/fix-task.md` for the task
   body. If `STATUS: BLOCKED`, record the blocker and the triager's smallest question; do not mint a
   fix row.
5. Announce the `FIX-NNN` id and severity. Do not start a fix — that is `/fix-issue` or `/assign`.
