---
description: Move settled fix rows (DONE / SKIPPED) out of backlog.md into backlog-archive.md to keep the backlog lean.
argument-hint: "[FIX-NNN | all-done]"
---

Keep `docs/backlog.md` lean by relocating settled rows. Markdown-only; never touches code, git, or
tracker state.

1. Resolve targets:
   - `FIX-NNN` → that one row (must be `DONE` or `SKIPPED`; refuse otherwise).
   - `all-done` (or no arg) → every row whose status is `DONE`.
2. For each target, **move** (not copy) the task-table row **and** its task body block from
   `docs/backlog.md` to `docs/backlog-archive.md` (create the archive file with a header if absent).
   Carry the row's `created`/`updated` timestamps through verbatim, and stamp `archived` with
   `date -u +%Y-%m-%dT%H:%M:%SZ` — the archive row keeps the full `created → updated → archived`
   history, not just the final state.
3. Leave `docs/issue-log.md` untouched (its `DONE` status is the durable record) and do not remove
   `F-NNN` findings — the ledger is append-only.
4. Print what was archived (ids + issue #s) and the remaining open-row count. Idempotent: a row
   already archived is skipped.
