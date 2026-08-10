# Changelog

## [3.6.2] — 2026-08-10

Sorted the loose ends from the previous pass:
- `docs/templates/review-report.md`'s example table dropped its leading `#` column — it never
  matched the actual 6-column shape (`severity | category | location | scenario | fix | verdict`)
  that caused the 3.5.1 label-classifier bug in the first place. Docs-only, no script parses this
  template, but leaving the same wrong shape sitting in a template file was exactly the kind of thing
  that bug came from.
- PR #3's description updated to cover the 4 follow-up commits that landed on it since it was opened
  (label-classifier fix, `plugin-validate.yml`, wiring `validate-project.ps1` into it, Bitbucket
  removal) — it only described the original commit before.

## [3.6.1] — 2026-08-10

Likely bug fix in `host-gitlab.sh`'s `pr-diff` — **unconfirmed, no live GitLab access to verify
against**, flagged as such deliberately rather than claimed as fixed with confidence.

Previous code hit `$API/merge_requests/$1.diff` where `$API` is under `/api/v4/projects/...`. The
`.diff`/`.patch` suffix trick is a real GitLab feature but belongs to the **web UI**
(`.../-/merge_requests/<iid>.diff`), not the versioned REST API namespace — appending it to an API
path isn't documented API behavior as far as available knowledge goes. Looks like GitHub's `gh pr
diff` shape got carried over by analogy without checking GitLab's actual API surface.

Replaced with GitLab's real, documented endpoint: `GET /merge_requests/:iid/changes` (returns a
`changes` array of `old_path`/`new_path`/`diff` per file, without `diff --git`/`---`/`+++` header
lines of its own), reconstructed into a standard unified diff. This is a better-reasoned guess, not a
confirmed fix — still needs a real GitLab merge request to verify against before anyone should trust
`/review-pr`/`/work-issue` against a GitLab target's diff review end to end.

## [3.6.0] — 2026-08-10

**Bitbucket support removed.** GitHub is the only host actually in use — confirmed by the user — and
Bitbucket support had been dead weight since it was built: a full REST backend and a CI template,
never once exercised against a real Bitbucket repo (both 0002 and 0003 flagged this the whole time),
adding real maintenance surface (e.g. the 3.5.1 label-classifier bug had to be fixed in two CI
templates instead of one) for zero actual usage. See
`docs/adr/0005-drop-bitbucket-support.md`.

Removed:
- `scripts/host-bitbucket.sh`, `bitbucket-pipelines.yml` — deleted, not deprecated.
- Bitbucket detection from `host.sh`, the Bitbucket branch from `install-runtime.sh`.
- `BITBUCKET_BRANCH`/`BITBUCKET_PR_DESTINATION_BRANCH` fallbacks from `ci-guard.sh`/
  `ci-pr-meta-check.sh` (GitLab's `CI_COMMIT_REF_NAME`/`CI_MERGE_REQUEST_TARGET_BRANCH_NAME` stay).
- Every Bitbucket mention across `CLAUDE.md`, `README.md`, `WORKFLOW.md`, `docs/agent-system-plan.md`,
  `docs/findings.md`, `docs/review-rubric.md`, and 6 command files — `BUGRABBIT_BB_USER`/
  `BUGRABBIT_BB_TOKEN` setup instructions gone with it.

Unaffected: GitLab support (not requested for removal — flagged in the ADR that it carries the
identical "never live-tested" caveat Bitbucket always had, but that's a separate, unresolved gap, not
a reason to remove it too). The `host.sh` 10-op adapter contract itself is unchanged — this removes a
backend, not the pattern. ADR 0002/0003 status lines updated to point at 0005; their historical bodies
left as-is, per this project's own ADR-history convention.

Re-verified after removal: `claude plugin validate --strict`, `tests/validate-project.ps1`, all
`bash -n`/YAML/JSON checks, and a live `repo-status.sh`/`host.sh detect` run against this repo's real
GitHub remote — all pass, GitHub path unaffected.

## [3.5.3] — 2026-08-10

`plugin-validate.yml` now also runs `tests/validate-project.ps1` (the existing, more thorough
project-invariant check — repository-qualified identity, immutable action pins, reviewer isolation,
fail-closed gate semantics) via `pwsh` on every push and PR, alongside the manifest check added in
3.5.2. Flagged as a gap in that entry; closed here rather than left open, since it turned out to be
free — `pwsh` ships preinstalled on GitHub-hosted `ubuntu-latest` runners, so no self-hosted runner or
new infra is needed (unlike `bug-finder.yml`, which genuinely does need one — see issue #2, still
open, still correctly low-priority). Re-confirmed `validate-project.ps1` passes clean before wiring
it in.

## [3.5.2] — 2026-08-10

Added `.github/workflows/plugin-validate.yml`: runs `claude plugin validate . --strict` on every
push and pull request to this plugin's own repo (not copied into targets, same scope as
`release.yml`). Pure manifest/schema check, no model calls, no `ANTHROPIC_API_KEY` needed — a
standard `ubuntu-latest` runner is enough. Catches a broken `.claude-plugin/plugin.json` or
`marketplace.json` — the same check the community-marketplace review pipeline runs first — before it
lands on a branch, rather than only at release time or marketplace-submission time.

Claude Code CLI pinned to `2.1.226` in the workflow (not `@latest`), per the "no floating latest for
CI tooling" rule — bump deliberately when needed.

`tests/validate-project.ps1` (the existing, more thorough project-invariant check — repository-
qualified identity, action pins, reviewer isolation, fail-closed gate semantics) is still not wired
into any CI workflow; it remains a manual/local check per `WORKFLOW.md`. Flagged, not fixed here —
out of scope for this pass, worth a follow-up if it's wanted in CI too.

## [3.5.1] — 2026-08-10

Fix: the 3.5.0 label classifier applied **zero labels on every real review**, silently, always.

Routine state-check on the repo (validators, live smoke tests, and a manual read of the new v3.5.0
code) turned up a real bug: `bug-finder.yml`/`bitbucket-pipelines.yml`'s column-based label extraction
read `$3`/`$4` for severity/category, assuming a 7-column table with a leading `#`
(`# | severity | category | location | scenario | fix | verdict`). The actual table the CI prompt
asks for — and the rubric documents — has 6 columns with no `#`. `$3`/`$4` therefore read the
*category*/*location* values instead of *severity*/*category*, so neither the `critical|high|medium|
low` nor the `correctness|regression|security|efficiency|tests` match loop ever matched anything.
The step still printed "no labels applied" either way, so nothing looked broken.

Confirmed by generating a real review table from the exact CI prompt (`claude -p` against a synthetic
buggy diff) and running the actual extraction code against real model output, before and after:
before, `high`/`correctness` findings produced empty `SEV_COL`/`CAT_COL`; after switching to `$2`/
`$3`, the same output correctly produced `severity:high category:correctness category:tests`. Also
re-verified the clean/empty-review case still produces zero labels, correctly, post-fix.

Fixed in both `bug-finder.yml` and `bitbucket-pipelines.yml` (identical bug in both, since one mirrors
the other). Corrected the matching column-order claim in
`docs/adr/0004-label-classifier-and-ledger-timestamps.md`'s Consequences section rather than rewriting
it, per this project's own ADR-history convention.

Also live-verified in this pass (closing a gap 3.5.0 had flagged as untested): `host.sh issue-label`
against the real issue #2 on this repo — `severity:low` did not exist as a label before, and the
`gh api` call auto-created and applied it as claimed. `claude plugin validate --strict` and
`tests/validate-project.ps1` both still pass against the full current tree.

## [3.5.0] — 2026-08-08

Host-label classifier + ledger timestamps — an audit-trail pass. See
`docs/adr/0004-label-classifier-and-ledger-timestamps.md` for full rationale.

Added:
- `host.sh issue-label`/`pr-label` ops (GitHub: `gh api`, auto-creates unknown labels; GitLab:
  `add_labels`, same auto-create; Bitbucket: no-op + note, no label concept there).
- `bug-triager` labels the issue `severity:<level>` at triage time; `pr-reviewer` labels the PR
  `severity:<max>` + one `category:<c>` per distinct category, on `/review-pr` and in CI
  (`bug-finder.yml`, `bitbucket-pipelines.yml` — a best-effort grep over the review's markdown table,
  since CI has no structured agent Return to read).
- `docs/backlog.md` rows: `created`/`updated` UTC columns. `docs/findings.md` rows: `raised`/`updated`.
  Carried through by `/archive-task` into `docs/backlog-archive.md`, not dropped.
- `/status-check`'s `STALE-DONE`/`STALE-PARTIAL` now reports how stale, using `updated`.

Fixed in the same pass: `CLAUDE.md` §6 rule numbers shifted (a new rule 7 was inserted) — updated the
two places that pointed at the old numbers by number (`scripts/gate.sh`'s comment, `docs/findings.md`'s
cross-reference) rather than by name. `commands/review-pr.md` gained a new step 5 (labeling), so its
own internal "step 5" self-reference and `docs/findings.md`'s "`/review-pr` step 5" reference both
became step 6 — fixed. Historical CHANGELOG entries citing the old rule numbers are left as-is,
same policy as the 3.0.0 rename: they're accurate to what CLAUDE.md said at the time.

Real bug caught during verification, fixed before landing: the CI label-extraction step originally
grepped whole markdown-table *rows* for known severity/category words, which false-positived
`category:regression` on a review whose only real categories were `correctness`/`tests` — the word
"regression" appeared inside an unrelated suggested-fix sentence ("add a regression test"). Fixed by
reading the severity/category *columns* by position instead of the whole row text; re-verified
against both a real findings table and a clean/empty-review table.

Known gaps: labeling and the timestamp-stamping commands were not exercised against a live issue/PR
in this change (the column-parsing logic itself was tested standalone, not through a real `gh`/GitLab
call) — see the ADR's Consequences section for exactly what's unverified.

## [3.4.0] — 2026-08-08

GitLab adapter, Bitbucket CI template, and dependency/SAST/SBOM scanning in `gate.sh`. See
`docs/adr/0003-gitlab-adapter-bitbucket-ci-and-gate-security-scans.md` for full rationale, including
what was explicitly declined (DAST, true cross-repo reasoning, ephemeral microVMs, CI/CD-integrated
temporal debugging) and why.

Added:
- `scripts/host-gitlab.sh` — third `host.sh` backend (GitLab REST v4, same 10-op contract, no
  merge/create-PR op). Auth via `BUGRABBIT_GL_TOKEN`. `host.sh detect` now matches `gitlab.com`.
- `bitbucket-pipelines.yml` — Bitbucket Pipelines CI template, mirrors `bug-finder.yml`'s
  guard→pr-meta-check→diff→review→comment shape. `install-runtime.sh` installs it (+ the
  `host-bitbucket.sh` backend into `.claude/scripts/`) on Bitbucket targets.
- `gate.sh`: `osv-scanner` (dependency/SCA, HARD on a known-vulnerable dependency), `semgrep` (SAST,
  HARD on a rule match, respects a target's own `.semgrep.yml`/`.semgrep/`), `syft` (SBOM,
  informational-only, written to a temp file — never left in the target tree). All three optional
  installs, same WARN-if-absent pattern as `gitleaks`.

Fixed (found while building the above, both real bugs, not scope extensions):
- `gate.sh`'s security scanners (including the `gitleaks` step shipped in 3.2.0) treated *any*
  nonzero exit as "found something" and hard-failed the gate. Live-testing `semgrep` here hit a
  Windows encoding crash (exit 2) that got wrongly reported as a finding. All four scanners now
  share a `sec_scan` helper: exit 1 = real finding (HARD), any other nonzero = tool/config error
  (WARN) — a crashing scanner isn't a security result.
- `ci-guard.sh`/`ci-pr-meta-check.sh` only read GitHub's branch env vars before falling back to
  local git, which resolves to a detached `HEAD` on Bitbucket Pipelines — silently defeating the
  protected-branch guard there. Both now also read Bitbucket's and GitLab CI's equivalents.

Known gaps: none of `host-gitlab.sh`, `osv-scanner`, `semgrep`'s HARD-fail path, or `syft` were
exercised against a real finding/live host (no GitLab repo available; `gitleaks`/`osv-scanner`/`syft`
aren't installed in this dev environment). Syntax-checked; `semgrep`'s WARN path was live-verified.

## [3.3.1] — 2026-08-08

Clarified and extended (no behavior reversal — confirmed with the user): findings were already
chat + `docs/findings.md` by default, with PR/issue comments opt-in-only locally (`/review-pr` step
5) and CI (`bug-finder.yml`) as the one path that always posts, per ADR 0001 rule 12 — that stays.
Documented this explicitly in `docs/findings.md`. Extended `memory_insight` (added to `bug-triager`/
`bug-fixer` in 3.3.0) to `pr-reviewer`: a *recurring, repo-wide* finding (not a one-off) can now be
promoted to `docs/bugrabbit-memory.md` via `/review-pr` and `/review-diff`, same Coordinator-append
model as the other two agents.

## [3.3.0] — 2026-08-08

Three named practices folded into `docs/fix-playbook.md`, plus a new cross-fix memory ledger.

Added:
- `docs/bugrabbit-memory.md` — durable, cross-fix insights about a target repo (architecture facts,
  recurring root causes, footguns, flaky-test notes). Coordinator-owned control-plane file, same
  write model as `docs/backlog.md`/`docs/findings.md`: agents surface an optional `memory_insight`
  in their Return, the Coordinator appends the row — agents never edit it directly.
- **Harness engineering** (playbook step 1): reproduction must be a runnable artifact (script/failing
  test), not prose steps — reused as both the before/after evidence and `qa-verifier`'s test seed.
- **Graph engineering** (playbook step 2): `trace_path` walked both directions (callers for blast
  radius, callees for depth) until the cause site has no simpler upstream explanation.
- **Loop engineering** (playbook step 4): every bounded corrective loop (gate.sh cap 5, review-fix
  cap 3) now also terminates early on a stalled signal — identical failure two iterations running
  aborts rather than burning the rest of the cap.
- Playbook step 0 (check memory before starting) and step 7 (surface memory sparingly after).

Changed: `CLAUDE.md` (§2 control-plane file list, §9 reference list), `bug-triager.md`/`bug-fixer.md`
(`memory_insight` in Return + Inputs), `commands/triage-issue.md`/`work-issue.md` (Coordinator
appends the row on return), `docs/agent-system-plan.md` layout diagram.

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
