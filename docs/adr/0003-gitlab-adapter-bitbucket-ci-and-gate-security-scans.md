# 0003. GitLab adapter, Bitbucket CI template, and gate.sh dependency/SAST/SBOM scans

**Status:** Accepted, Bitbucket CI template portion retracted by [0005](0005-drop-bitbucket-support.md)
**Date:** 2026-08-08
**Amends:** [0002](0002-host-agnostic-issue-pr-adapter.md) (does not supersede it — extends the same
adapter contract to a third host and fills in scope 0002 explicitly deferred)

## Context

0002 shipped the GitHub/Bitbucket adapter and deliberately deferred three things: a Bitbucket
Pipelines CI template, a GitLab backend, and anything beyond secret scanning in `gate.sh`. The user
asked for all three, plus dependency (SCA) and static-analysis (SAST) scanning "before they ship,"
plus a laundry list of aspirational product-vision items (semantic execution graphs, ephemeral
microVMs, temporal debugging via deployment-timeline correlation, cross-repo reasoning, DAST).

## Decision — built

- **`scripts/host-gitlab.sh`**: GitLab REST v4 backend, same 10-op contract as GitHub/Bitbucket, no
  `pr-create`/`pr-merge` op (same structural guarantee as 0002). Auth via `BUGRABBIT_GL_TOKEN`
  (`PRIVATE-TOKEN` header) — no `glab auth login` flow assumed. `host.sh detect` now matches
  `gitlab.com`; `VP_HOST=gitlab` covers self-hosted GitLab.
- **`bitbucket-pipelines.yml`**: Bitbucket Pipelines equivalent of `bug-finder.yml` — same
  guard → pr-meta-check → diff → local-Claude-review → post-comment shape, self-hosted-runner-only,
  never merges. `install-runtime.sh` now installs it (and the matching `host-bitbucket.sh` backend
  into `.claude/scripts/`) when the target's detected host is `bitbucket`, mirroring the existing
  GitHub branch. `bug-finder.yml` itself was also switched from a raw `gh pr comment` call to
  `scripts/host.sh pr-comment` for consistency between the two templates.
- **Portability fix, found while wiring the above**: `ci-guard.sh` and `ci-pr-meta-check.sh` only
  read `$GITHUB_HEAD_REF`/`$GITHUB_BASE_REF` before falling back to local git — on Bitbucket
  Pipelines that fallback resolves to a detached `HEAD`, silently defeating the protected-branch
  check. Both scripts now also read `$BITBUCKET_BRANCH`/`$BITBUCKET_PR_DESTINATION_BRANCH` and
  GitLab CI's `$CI_COMMIT_REF_NAME`/`$CI_MERGE_REQUEST_TARGET_BRANCH_NAME`, so the guard is honest
  on all three hosts, not just the one it happened to be written for.
- **`gate.sh`**: added `osv-scanner` (dependency/SCA), `semgrep` (SAST), and `syft` (SBOM,
  informational-only) alongside the existing `gitleaks` step — same install-optional, HARD-if-found
  pattern. **Correctness fix found while testing `semgrep` live**: the original `gitleaks` step (and
  the first draft of `osv-scanner`/`semgrep`) treated *any* nonzero exit as "found something" and
  hard-failed the gate. Live-running `semgrep --config auto` against this repo crashed with a
  Windows-specific encoding bug (exit code 2, not a finding) and the gate wrongly reported FAIL. All
  four scanners now go through a shared `sec_scan` helper that only hard-fails on exit code 1
  (the tool ran and found something); any other nonzero exit WARNs as a tool/config error instead —
  a crashing scanner is not a security finding, and treating it as one just teaches people to bypass
  the gate.

## Decision — explicitly declined (scoped, not built)

Recorded here so "not built" doesn't quietly become "forgotten":

- **DAST.** Fundamentally different shape from SCA/SAST/secrets: it requires a *running* instance of
  the target application (boot command, listen port, auth, seed data) which is bespoke per repo and
  not something a generic `gate.sh` step can infer. A real version needs the target repo to declare
  how to start itself (e.g. a `docs/dast.yml` the Coordinator reads) — that's a new per-target
  contract, not a tool install, and wasn't asked for at that level of specificity. Not built.
- **Semantic execution graphs / true cross-repo reasoning.** The realistic version of "semantic
  execution graph" is what `docs/fix-playbook.md`'s graph-engineering step (`trace_path` walked both
  directions) already does with codebase-memory MCP, single-repo. Genuine cross-repo reasoning needs
  multi-repo indexing this MCP server isn't shown to support today — not built, would need its own
  scoped design once there's a concrete multi-repo scenario to design against.
- **Ephemeral microVMs.** Infrastructure provisioning (Firecracker/Docker orchestration, networking,
  teardown) is a different kind of project than a markdown+bash Claude Code plugin. `gate.sh` running
  in the target's own checkout *is* the sandbox today. Not built; would be a dedicated infra
  workstream, not a gate.sh addition.
- **Temporal debugging via deployment-timeline/feature-flag correlation.** The literal ask needs
  integration with each target's specific CI/CD and feature-flag systems — not generically buildable.
  A bounded, real version using only `git log` (correlate commits touching the affected file/lines
  around the issue's reported date) is plausible future playbook-step scope, but wasn't built here —
  flagged as a candidate, not shipped.

## Consequences

- **+** All three hosts (GitHub, Bitbucket Cloud, GitLab) now share one 10-op adapter contract and
  the "no merge/create-PR op" structural guarantee; GitHub and Bitbucket also get matching CI review
  templates.
- **+** `gate.sh` catches known-vulnerable dependencies and common SAST patterns before a fix ships,
  not just leaked secrets — closing part of the "catch vulnerabilities before they ship" ask.
- **+** The exit-code-discrimination fix makes all four scanners correctly distinguish "found a real
  issue" from "the tool itself broke," which the original `gitleaks` step (shipped in 3.2.0) did not
  do — a latent bug fixed before it caused a false-block in the wild.
- **−** None of `host-gitlab.sh`, `osv-scanner`, `semgrep`'s HARD-fail path, or `syft` were exercised
  against a real finding/live host in this change (no GitLab repo, and none of `gitleaks`/
  `osv-scanner`/`syft` are installed in this dev environment) — syntax-checked and, where the tool
  was available (`semgrep`, in its WARN/crash path only), live-run. Treat all four as unverified on
  their HARD-fail path until exercised for real.
- **−** DAST, true cross-repo reasoning, microVM sandboxing, and CI/CD-integrated temporal debugging
  remain out of scope — see the declined list above for what a real version of each would need.
