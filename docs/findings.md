# Findings ledger

Append-only record of findings raised by `pr-reviewer` / `qa-verifier` during `/work-issue`,
`/autofix-issues`, `/review-pr`, and `/review-diff`. Each finding gets one `F-NNN` row; rows are
**appended, never rewritten** (correct a finding by adding a follow-up row or flipping its `status`
via `/findings close`, not by editing history).

This is a **record, not an enforcement gate** — it gives every finding a durable id so it survives a
single agent Return and can be tracked to closure. Delivery is **chat + this ledger by default**;
locally, a finding is only ever posted as a PR/issue comment if the user explicitly asks (`/review-pr`
step 6). CI (`bug-finder.yml`) is the one path that always posts a PR comment, since it has no chat
to report to instead — see CLAUDE.md rule 13. A finding that turns out to be a *recurring, repo-wide*
pattern (not a one-off) gets promoted to `docs/bugrabbit-memory.md` via the reviewer's optional
`memory_insight` — this ledger stays the per-finding record, memory stays the durable-pattern record.

## Row format

`F-NNN` · **severity** {critical | high | medium | low} · **location** (`file:line`) · **issue**
(scenario) · **required action** · **status** {open | fixed | deferred | waived} · **source**
(agent + PR/issue/diff ref) · **raised** (UTC, stamped once when the row is first appended) ·
**updated** (UTC, re-stamped every time `status` changes — via `/findings close` or a re-review).
The `raised`→`updated` pair is the audit trail: how long a finding sat before it was fixed/deferred/
waived, not just its current state.

When `pr-reviewer` finds anything on an actual PR (`/review-pr`, or CI), the Coordinator also applies
`severity:<max>` + one `category:<c>` per distinct category as **PR labels** via `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh
pr-label` — best-effort, host-dependent (no-op with a note on Bitbucket). `/review-diff` never labels
(no PR/issue exists for a working-tree diff).

| F-NNN | Severity | Location | Issue (scenario) | Required action | Status | Source | Raised (UTC) | Updated (UTC) |
|-------|----------|----------|------------------|-----------------|--------|--------|---------------|---------------|
| — | — | — | (none yet — no reviews run) | — | — | — | — | — |
