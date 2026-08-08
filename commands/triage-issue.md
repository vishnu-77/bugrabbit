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
   title, severity, root-cause `file:line`, status `READY`, `created`/`updated` both stamped `date -u
   +%Y-%m-%dT%H:%M:%SZ`) using `docs/templates/fix-task.md` for the task body. If `STATUS: BLOCKED`,
   record the blocker and the triager's smallest question; do not mint a fix row. If the Return
   includes `memory_insight`, append one row to `docs/bugrabbit-memory.md` (both control-plane files,
   Coordinator-owned — the agent never edits them directly).
5. **Label the issue** with `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh issue-label $ARGUMENTS --label severity:<sev>` (the
   severity `bug-triager` returned). Best-effort — a host that can't label (Bitbucket) prints a note
   and continues; never block triage on this.
6. Announce the `FIX-NNN` id and severity. Do not start a fix — that is `/fix-issue` or `/assign`.
