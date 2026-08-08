---
description: Read-only bug-finding review of the local working diff or a commit range via pr-reviewer.
argument-hint: "[ref] (e.g. HEAD~3..HEAD, main...HEAD; default: working tree)"
---

Use the enclosing Git repository, or the `/set-repo` override. Review the local diff **$ARGUMENTS** (default: uncommitted
working tree) for bugs. Read-only.

1. Resolve the diff scope in the active repo:
   - `$ARGUMENTS` empty → `git diff` (working tree) + `git diff --staged`.
   - `$ARGUMENTS` a range/ref (`A..B`, `A...B`, a sha) → `git diff $ARGUMENTS`.
   If the diff is empty, say so and stop.
2. **Load** `${CLAUDE_PLUGIN_ROOT}/agents/pr-reviewer.md` by plugin-relative path; if absent, **REFUSE (fail-closed)**.
3. Spawn via the Task tool with **`model: sonnet`**, embedding the `pr-reviewer` spec **verbatim**,
   the diff scope + active repo path, and `docs/review-rubric.md`.
4. On return, record findings as `F-NNN` rows in `docs/findings.md` (source `pr-reviewer` +
   diff ref). If the Return includes `memory_insight`, append a row to `docs/bugrabbit-memory.md`
   too. Print the findings table (most-severe first) + verdict — this is the delivery, no PR/issue
   comment is posted anywhere.

No branch, no commit, no push — this is a read-only review of local changes.
