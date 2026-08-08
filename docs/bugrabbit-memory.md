# BugRabbit memory — durable insights about the active target repo

Append-only cross-fix knowledge for **this target repository** — the things `bug-triager` and
`bug-fixer` learn once and would otherwise re-derive on every future issue: non-obvious architecture
facts, recurring root-cause patterns, footguns, flaky-test notes. This is not a task ledger
(`docs/backlog.md`) or a review-findings ledger (`docs/findings.md`) — it's what those two agents
know about *how this codebase actually works* that isn't visible from reading any single file.

**Read this first**, alongside codebase-memory MCP, before triaging a new issue — it can save
re-walking a graph trace you already walked last month. **Write to it sparingly**: most fixes don't
teach anything durable; only append when the insight will plausibly save the *next* triage real time.
Rows are appended, never rewritten — correct a stale entry with a follow-up row marking the old one
`stale`, don't edit history.

## Row format

`M-NNN` · **area** (file/module/subsystem) · **insight** (the durable fact, one or two sentences) ·
**why it matters** (what it saves the next person from re-deriving) · **learned during** (`FIX-NNN` /
issue ref) · **status** {active | stale}.

| M-NNN | Area | Insight | Why it matters | Learned during | Status |
|-------|------|---------|-----------------|----------------|--------|
| — | — | (none yet — no fixes have landed an insight) | — | — | — |
