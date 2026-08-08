# WORKFLOW.md — dev guide for BugRabbit, the bug-fixing agent system

How a developer actually uses this system day to day. The design lives in
`docs/agent-system-plan.md`; the rules the agents follow live in `CLAUDE.md`. This file is the
hands-on guide.

---

## What this does

- **Auto-fix bugs from tracked issues** — reproduce → root-cause → smallest fix on a branch → push.
  **You open the PR** (agents never open/merge PRs).
- **Find bugs in every PR/commit** — a review pass locally (`/review-pr`, `/review-diff`) and in CI
  (`bug-finder.yml` on every PR/push, GitHub targets today).

One target repo per session. The active repo's host is the tracker — GitHub, Bitbucket Cloud, or
GitLab, via `scripts/host.sh`. Durable state is keyed by **`owner/repo#issue`**, so equal issue
numbers in different repositories never collide.

---

## One-time setup (per machine + per target repo)

```
brew install gh && gh auth login             # 1. GitHub target: GitHub CLI (prerequisite)
# or, for a Bitbucket Cloud target:
export BUGRABBIT_BB_USER=<username> BUGRABBIT_BB_TOKEN=<atlassian-api-token>
# or, for a GitLab target:
export BUGRABBIT_GL_TOKEN=<personal-or-project-access-token>
claude --plugin-dir <path-to-this-plugin>    # 2. dev/local test, OR:
/plugin install <git-url-of-this-plugin>     #    install it properly (any repo, no copying files in)
/bugrabbit:init-repo <repo-path>             # 3. bootstrap a target: git/remote check, copy CI, index it
```

`/bugrabbit:init-repo` prints a checklist (git ✓/✗, remote ✓/✗, host detected + authed ✓/✗, workflow
copied [GitHub only], indexed). Fix anything it flags. If the target isn't a git repo it offers
`git init`; add a remote with `git remote add origin <url>`.

**CI (optional):** `bug-finder.yml` needs a self-hosted runner labelled `claude` with local Claude
Code authed. No `ANTHROPIC_API_KEY` needed.

### Permissions

A plugin cannot bundle permission policy — paste this deny-list into your own `~/.claude/settings.json`
(or a specific project's `.claude/settings.json`) so agents can never open/merge PRs, force-push, or
run destructive `gh`/`git` commands:

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

This is enforced twice over: as a permission deny (above, your responsibility to add) and,
independently, `scripts/ci-guard.sh` / `scripts/ci-pr-meta-check.sh` fail closed in CI and when run
locally before a push.

### codebase-memory MCP (optional, not bundled)

Agents prefer `codebase-memory` MCP (`search_graph`, `trace_path`, `get_code_snippet`, `search_code`,
`index_repository`) for code discovery, falling back to Grep/Glob/Read when it's unavailable. This
plugin does not bundle an `.mcp.json` for it — if you have your own codebase-memory server, register
it yourself (project or user `mcpServers` config); otherwise the Grep/Glob/Read fallback is used
automatically.

---

## Repository selection is automatic

When BugRabbit is present inside a Git repository, every command automatically uses
`git rev-parse --show-toplevel`. No setup command is required. To control another repository, run
`/set-repo <repo-path>` as an explicit session override.

---

## Daily flows

### Fix one issue
```
/work-issue 12
```
Triage → fix on `fix/12-<slug>` → review (`pr-reviewer`) ∥ test (`qa-verifier`) → gate green → push.
Then **you** open the PR (it prints the branch + commit and reminds you). Idempotent: re-running
resumes an in-flight row and reuses the branch.

### Fix everything eligible (batch)
```
/autofix-issues                     # all open auto-fix issues
/autofix-issues --severity high     # only high+
/autofix-issues --limit 5 --dry-run # preview the work set, change nothing
```
Skips anything already `DONE`/`SKIPPED` or with an open PR. Ends with one comprehensive table
(processed / fixed / blocked / skipped, per-issue outcome + branch + findings).

### Review code for bugs (no fix)
```
/review-pr 34            # a PR (GitHub, Bitbucket, or GitLab)
/review-diff             # your uncommitted changes
/review-diff main...HEAD # a branch's changes
```
Findings land in `docs/findings.md` as `F-NNN` rows (severity + `file:line` + scenario).

### File an issue
```
/create-issue "scan crashes on empty result" --autofix
```
Dedups against open issues; `--autofix` labels it so the cron + `/autofix-issues` pick it up (GitHub
and GitLab support labels natively; Bitbucket issues have no label equivalent, `host.sh` ignores
`--label` there with a note).

### Track new issues automatically (cron)
```
/watch-issues run                    # poll once now
/watch-issues setup "*/15 * * * *"   # schedule polling every 15 min
```
The cron only **records** new live issues into `docs/issue-log.md` and notifies — it never fixes.

---

## Command reference

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

Agents (all Sonnet, dispatched for you): `bug-triager`, `bug-fixer`, `pr-reviewer`, `qa-verifier`.

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
git -C <target> push        # (already done by the agent)
gh pr create --fill --base main --head fix/12-<slug>   # you run this
```
Review the `bug-finder` comment CI posts, then merge when happy.

---

## Housekeeping

- **Idempotency:** everything is keyed by `owner/repo#issue`. Safe to re-run any command.
- **Drift:** run `/status-check` after big batches or cron runs — it flags `DUP-ROW`, `DUP-BRANCH`,
  `ORPHAN-ROW`, `STALE-DONE`, `UNTRACKED`, `DRIFT-STATUS` and proposes markdown-only fixes.
- **State files:** `docs/backlog.md` (fix tasks), `docs/findings.md` (review findings),
  `docs/issue-log.md` (cron seen-set). These are the source of truth — don't hand-edit mid-flow.
- **Quality bar:** tune what the reviewer flags in `docs/review-rubric.md`; tune fix discipline in
  `docs/fix-playbook.md`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "no repository found" | run inside a Git repository or use `/set-repo <path>` |
| issue/PR commands inert | host not authed → GitHub: `gh` not installed/authed, `brew install gh && gh auth login`. Bitbucket: `BUGRABBIT_BB_USER`/`BUGRABBIT_BB_TOKEN` unset. GitLab: `BUGRABBIT_GL_TOKEN` unset. |
| "not a git repo" | `/init-repo <path>` (offers `git init`) |
| reviewer/triage weak on code | target not indexed → `/init-repo` runs `index_repository` |
| CI job does nothing | no self-hosted `claude` runner, or empty diff |
| gate says "nothing to run" | no recognised toolchain (node/python/go/make) with runnable checks |

## Control-plane validation

On Windows or PowerShell CI, run:

```powershell
pwsh -File tests/validate-project.ps1
```

This checks repository-qualified identity, complete runtime packaging, immutable action pins,
reviewer isolation settings, and fail-closed gate semantics.
