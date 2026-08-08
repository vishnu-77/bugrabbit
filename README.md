# BugRabbit

**Autonomous debugging for Claude Code.**

BugRabbit is a Claude Code plugin: a reusable bug-fixing / code-review control plane for any Git
repository. It does two things:

- **Auto-fix bugs from tracked issues** — reproduce → root-cause → smallest fix on a branch → push.
  **You open the PR** (agents never open or merge PRs).
- **Find bugs in every PR/commit** — a review pass locally (`/review-pr`, `/review-diff`) and in CI
  (`bug-finder.yml` on every PR/push, GitHub targets today).

The active repo's host is the source of truth (issues + PRs) — GitHub, Bitbucket Cloud, or GitLab,
via `scripts/host.sh`. One target repo per session. Durable state is keyed by `owner/repo#issue`, so
equal issue numbers in different repositories never collide.

The design lives in `docs/agent-system-plan.md`; the rules the agents follow live in `CLAUDE.md`;
`WORKFLOW.md` is the hands-on day-to-day guide.

---

## Install

```
claude plugin marketplace add vishnu-77/bug-fixer   # this repo, self-hosts its own marketplace.json
claude plugin install bugrabbit@bugrabbit
```

Or for local dev/testing:

```
claude --plugin-dir <path-to-this-plugin>
```

Then bootstrap a target repository:

```
gh auth login                # GitHub target: GitHub CLI, prerequisite
# or, for a Bitbucket Cloud target:
export BUGRABBIT_BB_USER=<username> BUGRABBIT_BB_TOKEN=<atlassian-api-token>
# or, for a GitLab target:
export BUGRABBIT_GL_TOKEN=<personal-or-project-access-token>
/bugrabbit:init-repo <repo-path>
```

`/bugrabbit:init-repo` prints a checklist (git ✓/✗, remote ✓/✗, host detected + authed ✓/✗, runtime
installed, indexed) and offers `git init` if the target isn't yet a git repo.

**CI (optional):** `bug-finder.yml` needs a self-hosted runner labelled `claude` with local Claude
Code authed — no `ANTHROPIC_API_KEY` secret required.

### Required: permission deny-list

A plugin cannot bundle permission policy. Paste this into your own `~/.claude/settings.json` (or a
project's `.claude/settings.json`) so agents can never open/merge PRs, force-push, or run
destructive `gh`/`git` commands:

```json
{
  "permissions": {
    "deny": [
      "Bash(gh pr merge:*)",
      "Bash(gh pr create:*)",
      "Bash(gh merge:*)",
      "Bash(git push --force:*)",
      "Bash(git push -f:*)",
      "Bash(git push origin main:*)",
      "Bash(git push origin master:*)",
      "Bash(git push origin HEAD:main:*)",
      "Bash(git push origin HEAD:master:*)",
      "Bash(git commit --amend:*)",
      "Bash(git rebase:*)",
      "Bash(gh issue delete:*)",
      "Bash(gh repo delete:*)",
      "Bash(gh repo archive:*)",
      "Bash(gh release delete:*)",
      "Bash(gh cache delete:*)",
      "Bash(rm -rf:*)"
    ]
  }
}
```

This is enforced twice over: your deny-list above, and independently `scripts/ci-guard.sh` /
`scripts/ci-pr-meta-check.sh`, which fail closed in CI and when run locally before a push.

---

## Daily commands

| Command | What you get |
|---|---|
| `/set-repo <path>` | Optionally override the automatically detected repository. |
| `/init-repo [path]` | One-time bootstrap of a target. |
| `/create-issue "<title>" [--autofix]` | File an issue (deduped). |
| `/triage-issue <#>` | Read-only: severity + root cause + a `FIX-NNN` row. |
| `/work-issue <#>` | Full fix pipeline for one issue → pushed branch. |
| `/autofix-issues [flags]` | Batch fix all eligible issues + a report. |
| `/review-pr <#>` | Bug-review a PR. |
| `/review-diff [ref]` | Bug-review local changes / a range. |
| `/assign <FIX-NNN> <agent>` | Run one agent on one task. |
| `/watch-issues [run\|setup <cron>]` | Poll / schedule issue tracking. |
| `/status` | Backlog + open issues/PRs summary. |
| `/status-check` | Deep drift + dedup audit; reconcile state. |
| `/findings [list\|show\|close]` | The `F-NNN` findings ledger. |
| `/adr <title>` | Record an architecture decision. |

Every command is namespaced `/bugrabbit:<command>` once installed as a plugin (e.g.
`/bugrabbit:status`).

Agents dispatched on your behalf (all Sonnet): `bug-triager`, `bug-fixer`, `pr-reviewer`,
`qa-verifier`. See `WORKFLOW.md` for example flows (fixing one issue, batch autofix, review-only,
filing issues, and the tracking cron).

---

## What the agents will and won't do

| Will | Won't |
|---|---|
| Create + push a `fix/<#>-*` branch | Open or merge a PR (`gh pr create`/`merge` denied) |
| Make the smallest root-cause change | Refactor unrelated code / widen scope |
| Drive `gate.sh` to green + add a regression test | Push to `main`/`master`, force-push, rebase, amend |
| Cite findings with `file:line` + a failure scenario | Commit secrets / `.env` / tokens |
| Reuse an existing row/branch for an issue | Duplicate a `FIX-NNN` row or branch for one issue |

If a bug isn't reproducible or the cause is unclear, triage returns **BLOCKED** with one focused
question instead of guessing.

---

## After the agent pushes — you open the PR

```
gh pr create --fill --base main --head fix/12-<slug>
```

Review the `bug-finder` comment CI posts, then merge when happy. BugRabbit never opens or merges
PRs, deploys, or touches your Git history (`rebase`/`--amend`/force-push are all denied).

---

## More

- `WORKFLOW.md` — the full day-to-day guide, troubleshooting table, and control-plane validation.
- `docs/agent-system-plan.md` — architecture and design rationale.
- `CLAUDE.md` — the Coordinator's own operating rules (the system prompt driving all of this).
- `CHANGELOG.md` — version history.
