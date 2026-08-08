# Changelog

## [3.2.0] — 2026-08-08

`gate.sh` runs a `gitleaks` secret scan first, language-agnostic, before lint/typecheck/test/build:
HARD-fails the gate on any finding (`--redact`, so the leaked value itself never hits gate
output/logs), WARNs and skips if `gitleaks` isn't installed (same pattern as every other tool in the
gate). Does not count toward the gate's `RAN` tracking — it's an additional check, not a substitute
for toolchain verification. Verified locally: WARN path confirmed (gitleaks not installed in this
dev environment); the HARD-fail path was read through, not exercised against a real leaked secret.

## [3.1.0] — 2026-08-08

Host-agnostic issue/PR adapter: BugRabbit now works against **Bitbucket Cloud** targets, not just
GitHub. See `docs/adr/0002-host-agnostic-issue-pr-adapter.md`.

Added:
- `scripts/host.sh` — dispatcher that detects the active repo's host from its origin remote
  (`github.com`/`bitbucket.org`, override via `VP_HOST`) and forwards to a backend.
- `scripts/host-github.sh` — the original `gh` calls, lifted behind the adapter (behavior-identical).
- `scripts/host-bitbucket.sh` — new Bitbucket Cloud backend (REST API v2.0 via `curl`+`jq`, Basic
  auth via `BUGRABBIT_BB_USER`/`BUGRABBIT_BB_TOKEN`).
- `docs/adr/0002-host-agnostic-issue-pr-adapter.md` — supersedes 0001.

Changed:
- `poll-issues.sh`, `repo-status.sh`, `find-bugs.sh`, `install-runtime.sh` now call `host.sh` instead
  of `gh` directly. `install-runtime.sh` skips the GitHub Actions workflow template on non-GitHub
  hosts (no Bitbucket Pipelines equivalent yet).
- All issue/PR-facing commands (`create-issue`, `triage-issue`, `work-issue`, `review-pr`, `status`,
  `status-check`, `watch-issues`, `set-repo`, `init-repo`, `autofix-issues`) and the `bug-triager`/
  `pr-reviewer` agent specs now call `host.sh` and use host-neutral wording.
- `CLAUDE.md`, `docs/agent-system-plan.md`, `README.md`, `WORKFLOW.md` reworded where they asserted
  GitHub-exclusivity.

Deferred (documented in ADR 0002, not built): a Bitbucket Pipelines CI template, GitLab support,
self-hosted GitHub/Bitbucket Server auto-detection beyond the manual `VP_HOST` override.

Known gap: `host-bitbucket.sh` was syntax-checked and read through but not exercised against a live
Bitbucket Cloud repo in this change (none was available) — treat as unverified until a real
end-to-end pass happens. `host-github.sh`/the rewired scripts were verified live against this
plugin's own GitHub repo, output unchanged.

## [3.0.0] — 2026-08-07

Renamed the plugin from `bug-fixer` to **BugRabbit** — "autonomous debugging for Claude Code." No
behavioural change to the agents, gate, or workflow; this is a branding + identity release.

Breaking:
- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`: `name` changed
  `bug-fixer` → `bugrabbit`. The plugin command namespace changes accordingly:
  `/bug-fixer:<command>` → `/bugrabbit:<command>`. Existing installs should reinstall
  (`/plugin install <repo>`) to pick up the new slug; any scripts or muscle-memory invoking
  `/bug-fixer:*` need updating to `/bugrabbit:*`.
- Release tag prefix changed `bug-fixer--v*` → `bugrabbit--v*` (`.github/workflows/release.yml`).

Unchanged, on purpose:
- Sub-agent role names (`bug-triager`, `bug-fixer`, `pr-reviewer`, `qa-verifier`) — these describe
  the specialist's job, not the product, and stay as-is.
- The underlying GitHub repository path (`vishnu-77/bug-fixer`) — renaming the repo itself is a
  separate, human-driven action (GitHub repo settings), not part of this plugin-identity change.
- All agent behaviour, `gate.sh`, backlog/findings schemas, and the git/GitHub protocol in this file.

Added a top-level `README.md` (previously missing) covering install, one-time setup, daily
commands, and the permission deny-list — pulled from `WORKFLOW.md`, rebranded.

## [2.1.1] — 2026-08-04

Follow-up to 2.1.0: the new `PARTIAL` status was only wired into `docs/backlog.md` and
`repo-status.sh`, not into the places that actually check for `DONE`. Found by re-reading the whole
plugin after shipping, not by a second real run.

- `commands/autofix-issues.md`, `commands/work-issue.md`, `commands/assign.md`: dedup/skip checks now
  also recognise `PARTIAL` (a shipped, bounded slice) so it isn't silently re-picked-up or reassigned.
- `commands/status.md`: status legend list now includes `PARTIAL`.
- `commands/status-check.md`: added `STALE-PARTIAL` alongside `STALE-DONE` — with the caveat that an
  issue staying open for a `PARTIAL` row's *deferred remainder* is expected, not itself stale; only
  flag when the shipped slice has no PR at all.
- `agents/pr-reviewer.md`: bumped its own `version: 1.0.0 -> 1.1.0` frontmatter to match the 2.1.0
  content change — missed in that release despite the plugin's own stated per-agent semver policy.
- Confirmed `commands/archive-task.md` correctly does **not** auto-archive `PARTIAL` rows (unlike
  `DONE`) — a partial row still has documented outstanding work, so this was already right and is
  left unchanged.

### Agents
- **pr-reviewer** 1.1.0 — added out-of-scope-finding guidance (from 2.1.0), version bump follow-up.

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
