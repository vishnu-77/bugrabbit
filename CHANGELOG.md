# Changelog

## [2.1.0] — 2026-08-04

Found via a real end-to-end run against a Node monorepo (13 GitHub issues triaged/fixed).

- **`gate.sh`**: fixed going `INCONCLUSIVE` on any monorepo whose root `package.json` has no
  lint/test/build scripts of its own (workspaces hold them instead). Now detects npm/yarn
  `workspaces` or a `pnpm-workspace.yaml` and gates every workspace that has runnable scripts,
  aggregating pass/fail correctly (no subshells, so `FAIL`/`RAN` state survives across workspaces).
  `resolve_repo` always normalises to the git root, so this was the only way `gate.sh` could ever be
  useful on this repo shape — there was no way to scope it to one workspace via `TARGET_DIR`.
- **`docs/backlog.md`**: added a `PARTIAL` status — a safe, bounded slice of an issue's full scope
  shipped, with the remainder deliberately deferred (e.g. it touches money/PII paths needing human
  sign-off, or spans far more call sites than one fix should). Previously this pattern had no home in
  the status legend and had to be improvised in free-text notes. `repo-status.sh` counts it.
- **`repo-status.sh`**: added a stale-close-candidate check — cross-references `DONE`/`PARTIAL`
  backlog rows against live GitHub issue state and flags any that the backlog already considers
  resolved but that are still `OPEN` on GitHub. On the run that motivated this, 10 of 13 audit-sourced
  issues turned out to already be fixed and merged weeks earlier, just never closed on GitHub —
  previously nothing surfaced this short of a full `/autofix-issues` pass re-discovering it.
- **`docs/fix-playbook.md`**: made the `codebase-memory` MCP fallback explicit and first-class —
  agents now treat "MCP not connected, fall back to Grep/Read/Glob" as a normal supported path
  instead of silently improvising it every run. Also documents the `PARTIAL` pattern from above.
- **`agents/pr-reviewer.md`**: added guidance for a real bug found outside the current issue's scope
  (e.g. a tooling/hook bug noticed while reviewing a branch) — report it, say plainly it's out of
  scope, and let the Coordinator spin it off separately rather than folding it into or blocking the
  current fix.
- **`commands/init-repo.md`** + **`scripts/install-runtime.sh`**: bootstrap now runs one baseline
  `gate.sh` pass (informational only, never blocks install) and reports pre-existing toolchain gaps
  up front — so a broken test runner or a missing lint config is known at `/init-repo` time, not
  rediscovered mid-fix on the first `/work-issue`.

## [2.0.1] — 2026-07-19

- Added `.github/workflows/release.yml`: automates tag + GitHub Release creation on every future
  `plugin.json` version bump (this release is its first live test).
- Extended `tests/validate-project.ps1` to check the new workflow's hardening (pinned checkout,
  timeout, minimal permissions, re-tag guard).

## [2.0.0] — 2026-07-19

Breaking: distribution and invocation both change — this is no longer a `.claude/` folder you copy
into a repo, it's an installable plugin (`/bug-fixer:<command>` instead of `/<command>`).

- Restructured as an installable Claude Code plugin: added `.claude-plugin/plugin.json`; moved
  `.claude/agents`, `.claude/commands`, `.claude/scripts` to plugin-root `agents/`, `commands/`,
  `scripts/`; split the `SessionStart` hook into `hooks/hooks.json` (the permission deny-list is not
  bundled — see `WORKFLOW.md`'s Permissions section). Commands/agents/scripts now reference their own
  bundled files via `${CLAUDE_PLUGIN_ROOT}` instead of `.claude/`-relative paths.
- Added `.claude-plugin/marketplace.json` (self-referencing, `source: "./"`) so
  `claude plugin marketplace add <repo>` + `claude plugin install bug-fixer@bug-fixer` work directly
  from the GitHub repo — `claude plugin install` requires an actual marketplace manifest, not just
  `plugin.json`.
- Fixed `repo-status.sh`/`poll-issues.sh` using `gh -C <path>` (not a valid `gh` flag — `gh` has no
  directory option, only `-R owner/repo`), which silently degraded GitHub state for any target repo
  other than the enclosing one. Both now derive `owner/repo` and use `gh ... -R`.
- Fixed the `owner/repo` slug-extraction regex (`sed -E`'s non-greedy `+?` is not honoured by POSIX
  ERE, so it left a trailing `.git` on the slug) that fed the broken `-C` calls above.
- Fixed malformed YAML frontmatter (unquoted `[...]` in `argument-hint`) in 7 command files, caught by
  `claude plugin validate`.

## 1.2.0 — 2026-07-17

- Make bug-fixer repository-local and repo-agnostic: operational scripts automatically resolve the
  enclosing Git root.
- Keep `/set-repo` and `VP_ACTIVE_REPO` as optional overrides for cross-tree operation.
- Centralize target resolution in `.claude/scripts/resolve-repo.sh` and validate adoption.

## 1.1.0 — 2026-07-17

- Scope durable issue identity by `owner/repo#issue` to prevent cross-repository collisions.
- Add a versioned, conflict-safe installer for the complete target-repository CI runtime.
- Make empty quality gates inconclusive instead of successful.
- Harden AI review CI with an immutable checkout pin, fork exclusion, disabled model tools,
  non-persisted credentials, bounded input, and a timeout.
- Add a deterministic PowerShell invariant test suite.

All notable changes to the bug-fixing agent system are recorded here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); agents are versioned
per-agent (semver) via the `version:` field in each `agents/*.md` frontmatter. Plugin releases are
cut as git tags (`bug-fixer--vMAJOR.MINOR.PATCH`, via `claude plugin tag`) and summarised below.

## [1.0.0] - 2026-07-16

Initial versioned release. Moved the control plane into a self-contained `bug-fixer/` repo and
removed all workspace-specific (VP) references so it is portable to any target repo.

### Agents
- **bug-fixer** 1.0.0 — smallest root-cause fix for one fix-task; drives `gate.sh` green; pushes the branch.
- **bug-triager** 1.0.0 — read-only triage of one GitHub issue; emits a fix-task spec.
- **pr-reviewer** 1.0.0 — read-only bug-finding review against the rubric; structured findings.
- **qa-verifier** 1.0.0 — adds minimal tests to lock a fix; re-runs `gate.sh`.

### Changed
- Made the control plane portable: dropped all VP / `personal/` / `threat-scan/` references from
  `CLAUDE.md`, `docs/`, `.claude/`, and scripts.
- Renamed `docs/vp-agent-system-plan.md` → `docs/agent-system-plan.md`.
- Added `version:` to every agent frontmatter.
