# Fix playbook — root-cause fixing discipline

The workflow `bug-triager` and `bug-fixer` follow. The goal is the **smallest correct change at the
root cause**, with evidence.

## Flow

```
reproduce → locate cause (not symptom) → smallest fix → gate green → verify (before/after) → push branch
```

## 1. Reproduce first
- Establish the smallest reliable reproduction: a command, an input, or a failing test.
- If you cannot reproduce, **stop** and state what is missing. Never fix a bug you cannot see.

## 2. Locate the cause, not the symptom
- Use **codebase-memory MCP if it's connected** (`search_code` to find the site, `trace_path` for
  call/data flow, `get_code_snippet` to read) — it's the fast path when available. If it isn't
  connected in this environment, that's a normal, fully-supported path too: fall back to
  Grep/Read/Glob directly and keep going, no need to stop and report the gap each time.
- Separate the **symptom site** (where it blows up) from the **cause site** (why). Fix the cause.
- Map the **blast radius**: callers/dependents of the code you will change (`trace_path`, or Grep for
  callers if MCP is unavailable).

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

## 4. Gate green
- Run `${CLAUDE_PLUGIN_ROOT}/scripts/gate.sh` and iterate to green (cap 5). If the toolchain is absent, note it —
  CI enforces the full set.

## 5. Verify (evidence)
- Show the reproduction failing **before** and passing **after**.
- Report: `Done / Verified / Not verified / Residual risk`.

## 6. Branch + commit + push
- Branch `fix/<issue#>-<slug>` (reuse an existing one for the same issue).
- Commit `#<issue> <type>(<scope>): <summary>` — no attribution trailers.
- `git push -u origin <branch>`. **Do not open or merge a PR** — the human does.

## Anti-patterns (reject)
- Symptom masking (catch-and-ignore, defensive `if` that hides the real bug).
- Widening scope to "improve" nearby code.
- Committing secrets, `.env`, or generated artefacts.
- A fix with no reproduction and no verification.
