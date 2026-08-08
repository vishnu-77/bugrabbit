# Fix playbook — root-cause fixing discipline

The workflow `bug-triager` and `bug-fixer` follow. The goal is the **smallest correct change at the
root cause**, with evidence.

## Flow

```
check memory → reproduce (harness) → locate cause (graph) → smallest fix → gate green (loop) →
verify (before/after) → push branch → surface memory
```

## 0. Check memory first
- Skim `docs/bugrabbit-memory.md` for durable insights about the area you're about to touch —
  known footguns, prior root causes nearby, non-obvious architecture facts. Cheap, and it can save
  re-walking a graph trace someone already walked.

## 1. Reproduce first (harness engineering)
- Establish the smallest reliable reproduction: a command, an input, or a failing test.
- If you cannot reproduce, **stop** and state what is missing. Never fix a bug you cannot see.
- **Build a harness, not just a description.** The reproduction should be a runnable artifact — a
  script, a failing test, a one-line repro command — not prose steps someone has to replay by hand.
  Prefer extending the target's existing test harness over inventing a new one. This harness is both
  the "before" evidence in step 5 and the seed for `qa-verifier`'s regression test — one artifact,
  reused twice, not redescribed twice.

## 2. Locate the cause, not the symptom (graph engineering)
- Use **codebase-memory MCP if it's connected** (`search_code` to find the site, `trace_path` for
  call/data flow, `get_code_snippet` to read) — it's the fast path when available. If it isn't
  connected in this environment, that's a normal, fully-supported path too: fall back to
  Grep/Read/Glob directly and keep going, no need to stop and report the gap each time.
- Separate the **symptom site** (where it blows up) from the **cause site** (why). Fix the cause.
- **Walk the graph both directions.** `trace_path` *callers* for blast radius (who breaks if this
  changes) and *callees* for depth (is the real cause one level further down than it first looks).
  Don't stop at the first plausible site — stop when the cause site has no simpler upstream
  explanation.
- Map the **blast radius**: callers/dependents of the code you will change (`trace_path`, or Grep for
  callers if MCP is unavailable).
- If the trace surfaces a non-obvious architecture fact (e.g. "auth is enforced in middleware X, not
  the route handlers"), that's memory-ledger material — see step 7.

## 3. Smallest change
- Change only what is needed to fix the cause. No drive-by refactors, no reformatting untouched code,
  no unrelated files.
- If the correct fix is large or ambiguous, return `NEEDS_FIX`/`BLOCKED` and let the Coordinator
  re-scope — do not sprawl.
- If a bounded first slice is safe but the full scope described by the issue isn't (e.g. it touches
  money/PII paths, or spans far more call sites than one fix should), ship the safe slice and mark it
  `PARTIAL` in `docs/backlog.md` (see the status legend there) rather than forcing the whole thing or
  refusing outright. Document exactly what's deferred and why, as its own follow-up.
- Prefer a fix that a staff engineer would approve: clear cause, minimal surface, reversible.

## 4. Gate green (loop engineering)
- Run `${CLAUDE_PLUGIN_ROOT}/scripts/gate.sh` and iterate to green (cap 5). If the toolchain is absent, note it —
  CI enforces the full set.
- **Every corrective loop is bounded and must show convergence.** This cap-5 gate loop, and the
  cap-3 review-fix loop in `/work-issue`, both terminate on iteration count *and* on a stalled
  signal: if iteration N+1 produces the identical failure as iteration N, stop early and return
  `BLOCKED`/`GATE_LOOP_EXHAUSTED` rather than burn the remaining cap on a loop that isn't moving.
  Cheap to abort beats slow to exhaust.

## 5. Verify (evidence)
- Show the reproduction failing **before** and passing **after** — the harness from step 1.
- Report: `Done / Verified / Not verified / Residual risk`.

## 6. Branch + commit + push
- Branch `fix/<issue#>-<slug>` (reuse an existing one for the same issue).
- Commit `#<issue> <type>(<scope>): <summary>` — no attribution trailers.
- `git push -u origin <branch>`. **Do not open or merge a PR** — the human does.

## 7. Surface memory (sparingly)
- If this triage/fix surfaced something durable — an architecture fact, a recurring root-cause
  pattern, a footgun, a flaky-test note — put it in your Return as `memory_insight`. Most fixes teach
  nothing durable; omit the field when that's the case. `docs/bugrabbit-memory.md` is a
  Coordinator-owned control-plane file (like `docs/backlog.md`) — the Coordinator appends the row
  from your Return, you don't edit it directly. This is what step 0 reads next time.

## Anti-patterns (reject)
- Symptom masking (catch-and-ignore, defensive `if` that hides the real bug).
- Widening scope to "improve" nearby code.
- Committing secrets, `.env`, or generated artefacts.
- A fix with no reproduction and no verification.
