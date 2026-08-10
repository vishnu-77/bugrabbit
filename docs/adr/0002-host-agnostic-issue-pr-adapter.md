# 0002. Host-agnostic issue/PR adapter (GitHub + Bitbucket Cloud)

**Status:** Accepted, Bitbucket portion retracted by [0005](0005-drop-bitbucket-support.md)
**Date:** 2026-08-08
**Supersedes:** [0001](0001-github-only-fix-and-push-no-pr.md)

## Context

0001 locked in "GitHub is the only source of truth." That was true of every issue/PR read-write
call in the codebase: every `gh issue`/`gh pr` invocation was an inline literal in scripts, command
markdown, and agent Bash allow-lists, with no abstraction anywhere. The plugin's own description
claims "for any repo" — true for the git mechanics (branch/commit/push already work against any
remote via `resolve-repo.sh`), false for triage/review, which only ever spoke to GitHub. The user
asked for Bitbucket support to make that claim actually true.

## Decision

- **Introduce one chokepoint:** `scripts/host.sh`, implementing exactly the operations the plugin
  already calls — `detect`, `remote-slug`, `auth-status`, `issue-view`, `issue-list`, `issue-state`,
  `issue-create`, `pr-diff`, `pr-view`, `pr-list`, `pr-comment`. No speculative ops.
- **`host.sh` detects the host** from the origin remote (`github.com` → github, `bitbucket.org` →
  bitbucket; override via `VP_HOST` for Enterprise/Server domains) and dispatches to one backend
  file per host: `scripts/host-github.sh` (lift-and-shift of the original `gh` calls, behavior-
  identical) and `scripts/host-bitbucket.sh` (new — Bitbucket Cloud REST API v2.0 via `curl`+`jq`,
  Basic auth via `BUGRABBIT_BB_USER`/`BUGRABBIT_BB_TOKEN`, since Bitbucket has no `gh
  auth login`-equivalent OAuth flow or ubiquitous official CLI).
- **No `pr-create`/`pr-merge` op ever exists in the adapter, on any host.** This is deliberate: it
  keeps 0001's "agents never open/merge PRs" guarantee true structurally across every current and
  future backend, without needing a per-host deny-pattern to maintain (`ci-guard.sh`'s literal
  `gh pr merge`/`gh pr create` denies remain only as defense-in-depth for humans running raw `gh`
  locally).
- **Scope for v1:** GitHub full parity + Bitbucket Cloud issue+PR read/write. Explicitly deferred
  (both items below were later picked up — see [0003](0003-gitlab-adapter-bitbucket-ci-and-gate-security-scans.md)):
  - A `bitbucket-pipelines.yml` CI template — the CI event-model port (trigger semantics, context
    variables, runner equivalents) is a materially bigger, separate lift than the read/write
    adapter, and nothing in `/work-issue`/`/review-pr`/`/status` requires it. `/init-repo` on a
    non-GitHub host skips the workflow-file install with a warning and installs everything else.
  - GitLab — a future `host-gitlab.sh` against the same op contract (GitLab REST v4), once there's
    real demand.
  - Bitbucket/GitHub *Server* (self-hosted) auto-detection beyond the manual `VP_HOST` override.

## Consequences

- **+** `/triage-issue`, `/work-issue`, `/review-pr`, `/status`, `/autofix-issues`, and the polling
  cron now work against a Bitbucket Cloud target through the same commands, with GitHub behavior
  unchanged (verified live against this plugin's own GitHub repo before/after the refactor).
- **+** The "agents never open/merge PRs" property is now enforced by the adapter's shape, not just
  a deny-list — a new host backend cannot accidentally reintroduce merge/create-PR capability
  without a conscious contract change.
- **−** Bitbucket issue labels have no equivalent in the Bitbucket Issues API; `--label` is accepted
  and ignored there with a printed note, not silently dropped.
- **−** `host-bitbucket.sh` was not tested against a live Bitbucket Cloud repo in this change (none
  was available) — only syntax-checked and read through. Treat it as unverified until a real
  end-to-end pass (`init-repo` → `create-issue` → `triage-issue` → `work-issue` → `review-pr`)
  against an actual Bitbucket Cloud repo happens.
- **−** No CI review workflow exists yet for Bitbucket targets — `bug-finder.yml`'s "find bugs in
  every PR/commit" half only runs in CI on GitHub today; Bitbucket users get the local
  `/review-pr`/`/review-diff` commands but no automatic per-PR CI comment.
