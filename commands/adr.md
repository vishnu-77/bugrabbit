---
description: Create the next-numbered Architecture Decision Record in docs/adr/.
argument-hint: <short-title>
---

Create the next ADR in `docs/adr/` for decision **$ARGUMENTS**.

1. Find the highest existing `NNNN-*.md` in `docs/adr/`; the new number is that + 1 (zero-padded to
   4). First ADR is `0001`.
2. Write `docs/adr/<NNNN>-<kebab-title>.md` with: `# NNNN. <Title>`, **Status** (Proposed),
   **Context**, **Decision**, **Consequences** (trade-offs), **Date** (today).
3. Announce the file path. ADRs are Coordinator-owned; agents never write them.
