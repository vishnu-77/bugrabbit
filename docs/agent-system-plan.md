# bug-fixing agent system — design

Reusable control plane that (a) auto-fixes bugs from tracked issues and (b) finds bugs in
every PR/commit. Modelled on `polaris-sandbox-helm` / `polaris-shared-helm-charts`: a Coordinator +
pinned Sonnet sub-agents + slash commands + thin helper scripts + docs backlog + deny-guards.

## Principles
- **The active repo's host is the source of truth** (issues + PRs) — GitHub or Bitbucket Cloud today
  via `scripts/host.sh` (see `docs/adr/0002-host-agnostic-issue-pr-adapter.md`), GitLab planned. No
  Jira. Work keyed by **`owner/repo#issue`**.
- **Reusable**: auto-detects the enclosing Git root; `/set-repo` optionally targets a different repo.
- **Autonomy**: agents **fix + push a branch**, never open/merge PRs (human does). Enforced by
  `.claude/settings.json` deny + `ci-guard.sh`.
- **Local + CI**: slash commands locally; `bug-finder.yml` reviews in CI (self-hosted runner, local
  Claude Code, no API key).
- **Idempotent + dedup**: keyed by repository + issue; check-before-write everywhere; `/status-check` reconciles.
- **Thin scripts**: helpers gather/summarise/guard only — judgement lives in agents + rubric + playbook.

## Layout
```
bugrabbit/                      (plugin root)
  CLAUDE.md                     Coordinator system prompt (the detailed prompt)
  .claude/
    settings.json               deny-guards (no PR create/merge, no force/main push) + discovery hook
    agents/  bug-triager · bug-fixer · pr-reviewer · qa-verifier   (all model: sonnet)
    commands/ set-repo · init-repo · create-issue · triage-issue · work-issue ·
              autofix-issues · review-pr · review-diff · assign · watch-issues ·
              status · status-check · findings · adr
    scripts/ gate.sh · repo-status.sh · find-bugs.sh · ci-guard.sh · poll-issues.sh ·
             host.sh · host-github.sh · host-bitbucket.sh
  docs/
    agent-system-plan.md (this) · backlog.md · findings.md · issue-log.md
    review-rubric.md · fix-playbook.md · templates/{fix-task,review-report}.md · adr/
  .github/workflows/bug-finder.yml   TEMPLATE (copied into each target by /init-repo)
```

## Roles
| Agent | Mutates | Job |
|---|---|---|
| `bug-triager` | read-only | reproduce → severity → root cause (codebase-memory) → `fix-task` |
| `bug-fixer` | branch only | smallest root-cause fix → gate green → commit + push branch |
| `pr-reviewer` | read-only | review diff vs rubric → structured findings (file:line + scenario) |
| `qa-verifier` | tests only | minimal regression test locking the fix → re-run gate |

The Coordinator embeds each spec + task + active-repo path + reference doc into the Task prompt with
`model: sonnet` pinned (the harness does not auto-load a plugin's `agents/*`).

## Flows
```
single:  /work-issue N   → triage → assign bug-fixer → (pr-reviewer ∥ qa-verifier) → push branch
batch:   /autofix-issues → poll → select eligible (skip settled) → per-issue /work-issue → report
review:  /review-pr N | /review-diff [ref] → pr-reviewer → findings (F-NNN)
cron:    /watch-issues setup → poll-issues.sh → issue-log.md (track only) → notify
CI:      bug-finder.yml on PR/push → ci-guard assert → find diff → pr-reviewer → PR comment
```

## Idempotency + dedup (rule §13)
- **Key = `owner/repo#issue`.** One `FIX-NNN` row per composite key; one `fix/<#>-*` branch per issue within that repository.
- `docs/issue-log.md` = append-only seen-set (dedup by composite key), written by `poll-issues.sh`.
- `/work-issue` and `/autofix-issues` skip `DONE`/`SKIPPED` work and reuse existing branches/rows.
- `/status-check` detects `DUP-ROW`, `DUP-BRANCH`, `ORPHAN-ROW`, `STALE-DONE`, `UNTRACKED`,
  `UNWORKED`, `DRIFT-STATUS` and reconciles (markdown-only, human-approved).

## Prerequisites
- Host auth: `gh` CLI installed + authed for GitHub (`brew install gh && gh auth login`), or
  `BUGRABBIT_BB_USER`/`BUGRABBIT_BB_TOKEN` set for Bitbucket Cloud.
- Target is a git repo with a GitHub or Bitbucket Cloud remote (`/init-repo` checks/creates).
- Target indexed in codebase-memory MCP (`index_repository`).
- CI: a self-hosted runner labelled `claude` with authed local Claude Code. No `ANTHROPIC_API_KEY`.

## Verification
See the "Verification" section of the approved plan: gate on the target repo, index + `search_graph`,
`/review-diff` on a seeded bug, `/work-issue` produces a pushed branch (no PR), CI posts a comment and
never merges, deny-guards block `gh pr merge` / `git push origin main` (and `scripts/host.sh`
structurally has no merge/create-PR op on any host).

## Out of scope
Opening/merging PRs (human), deploying/releasing, cross-repo fixes in one branch, history rewrites.
