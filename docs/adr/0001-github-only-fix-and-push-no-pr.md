# 0001. GitHub-only, fix-and-push, agents never open/merge PRs

**Status:** Accepted
**Date:** 2026-07-16

## Context

This workspace needs a reusable agent system to (a) auto-fix bugs from GitHub issues and (b) find bugs in every
PR/commit, mirroring the `polaris-sandbox-helm` operating model (Coordinator + pinned Sonnet
sub-agents + slash commands + thin scripts + docs backlog + deny-guards). The workspace is multi-project
workspace; `gh` and git remotes are not yet wired.

## Decision

- **GitHub is the only source of truth** (issues + PRs). No Jira. Work is keyed by `owner/repo#issue`.
- **Reusable control plane**; one active target repo per session (`/set-repo`).
- **Autonomy = fix + push a branch; humans open and merge PRs.** `gh pr create`, `gh pr merge`,
  `git push --force`, and pushes to `main`/`master` are denied in `.claude/settings.json`, and
  `ci-guard.sh` enforces the same in CI.
- **Local + CI.** Slash commands drive work locally; `bug-finder.yml` reviews on `pull_request`/`push`
  using local Claude Code on a self-hosted runner (no `ANTHROPIC_API_KEY`).
- **Idempotency + dedup** keyed by repository + issue: `docs/issue-log.md` (cron seen-set), `docs/backlog.md`
  (one `FIX-NNN` per issue), `/status-check` reconciliation.
- **A cron tracks, never fixes** (`/watch-issues` → `poll-issues.sh`).

## Consequences

- **+** Safe by default: no accidental merges/history rewrites; human stays in the loop on PRs.
- **+** Portable across any target repo; no external tracker dependency.
- **−** CI needs a self-hosted runner with authed Claude Code (setup cost).
- **−** Humans must open PRs for pushed branches (extra step, by design).
- **−** GitHub-only means no Jira provenance; revisit if enterprise tracking is later required.
