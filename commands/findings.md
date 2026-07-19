---
description: View or append the F-NNN findings ledger.
argument-hint: "[list | show F-NNN | close F-NNN <status>]"
---

Manage `docs/findings.md` (append-only record of `pr-reviewer` / `qa-verifier` findings).

- **no args / `list`** — print the findings table, most-severe first; highlight `open` `critical`/
  `high`.
- **`show F-NNN`** — print that finding's full row.
- **`close F-NNN <status>`** where `<status>` ∈ {`fixed`, `deferred`, `waived`} — append a follow-up
  row flipping the status (never rewrite history); if `waived`, require a one-line human-authored
  reason and quote it verbatim.

Rows are `F-NNN · severity · location (file:line) · issue · required action · status · source`.
The ledger is a record, not an enforcement gate. No code changes here.
