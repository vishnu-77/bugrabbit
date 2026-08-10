# 0005. Drop Bitbucket support

**Status:** Accepted
**Date:** 2026-08-10
**Amends:** [0002](0002-host-agnostic-issue-pr-adapter.md), [0003](0003-gitlab-adapter-bitbucket-ci-and-gate-security-scans.md)
(retracts the Bitbucket-specific portions of both; the adapter contract and GitLab support they
introduced are unaffected)

## Context

0002 and 0003 built full Bitbucket Cloud support: `scripts/host-bitbucket.sh` (issue/PR read-write,
REST API v2.0), `bitbucket-pipelines.yml` (a CI review template mirroring `bug-finder.yml`), and
Bitbucket-specific wiring across `host.sh` detection, `install-runtime.sh`, and roughly fifteen docs/
command/agent files. Both ADRs flagged the same caveat at the time: none of it was ever exercised
against a real Bitbucket repo — no live target existed to test against, only syntax checks and
read-throughs.

That target never materialized. The user confirmed GitHub is the only host actually in use — there
is no Bitbucket repo this plugin operates on, nor a plan for one. Every line of Bitbucket-specific
code has been dead weight since it was written: a full backend script, a CI template, and pervasive
"GitHub, Bitbucket, or GitLab" phrasing across the docs, none of it ever run for real, all of it
adding real surface (a second REST API integration to keep correct, a second CI template to keep in
sync with `bug-finder.yml`'s shape) for zero actual usage.

## Decision

Remove Bitbucket support entirely, not just stop mentioning it:

- Deleted `scripts/host-bitbucket.sh` and `bitbucket-pipelines.yml`.
- `scripts/host.sh` no longer detects `bitbucket.org`; `install-runtime.sh` no longer has a
  Bitbucket branch.
- Every doc/command/agent/README/WORKFLOW mention of Bitbucket, `BUGRABBIT_BB_USER`/
  `BUGRABBIT_BB_TOKEN`, and Bitbucket-specific caveats (no label support, etc.) removed.
- `scripts/ci-guard.sh`/`scripts/ci-pr-meta-check.sh` dropped their `BITBUCKET_BRANCH`/
  `BITBUCKET_PR_DESTINATION_BRANCH` env-var fallbacks (added in 0003 for CI portability); the
  GitLab CI equivalents (`CI_COMMIT_REF_NAME`, `CI_MERGE_REQUEST_TARGET_BRANCH_NAME`) stay.

**GitLab support stays as-is** — not requested for removal, and architecturally independent (its own
backend, its own detection branch). Worth noting honestly: GitLab has the identical "never live-
tested against a real repo" caveat Bitbucket always had. It wasn't asked to go, so it isn't going,
but that gap is real and unresolved, not different in kind from what Bitbucket had.

The 10-op adapter contract itself (`host.sh` dispatch, no `pr-create`/`pr-merge` op ever) is
unaffected — this removes a backend, not the pattern.

## Consequences

- **+** Smaller surface: one fewer untested REST integration, one fewer CI template to keep in sync,
  ~15 fewer files carrying "and Bitbucket" branches that had to be read and reasoned about on every
  future change (e.g. the label-classifier column-index bug fixed in 3.5.1 touched both CI templates
  — one of which was Bitbucket's, never exercisable, pure maintenance cost for no benefit).
- **+** Docs collapse back to a true statement — "GitHub or GitLab" — instead of listing a host that
  was never actually reachable.
- **−** If Bitbucket support is wanted again later, this is a rebuild, not a revert-and-resume — the
  code is deleted, not disabled. Given it was never live-verified even once, treating a future rebuild
  as fresh work (informed by this attempt, but re-verified from scratch) is more honest than pretending
  a resurrected copy would still be trustworthy.
