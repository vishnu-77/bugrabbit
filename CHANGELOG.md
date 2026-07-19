# Changelog

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
