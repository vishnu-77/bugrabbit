# BugRabbit

**Autonomous debugging for Claude Code.**

BugRabbit turns Claude Code into a structured bug-fixing and code-review workflow for any Git repository.

Give it an issue, pull request, commit, or local diff. BugRabbit reproduces the problem, finds the root cause, prepares the smallest verified fix, and pushes it to an isolated branch.

**You stay in control of the PR and merge.**

```text
Issue → Reproduce → Root Cause → Fix → Test → Verify → Push Branch → You Review
```

---

## What BugRabbit does

### Fix tracked bugs

```text
/bugrabbit:work-issue 42
```

BugRabbit will:

1. Read the issue and repository context.
2. Reproduce the failure.
3. Identify the root cause.
4. Create an isolated `fix/42-*` branch.
5. Make the smallest necessary change.
6. Add regression coverage.
7. Run repository verification.
8. Push the branch.

It stops there.

BugRabbit **does not create or merge the pull request**.

---

### Find bugs in code changes

Review a pull request:

```text
/bugrabbit:review-pr 42
```

Review local changes:

```text
/bugrabbit:review-diff
```

Review a Git range:

```text
/bugrabbit:review-diff main..feature
```

Findings include:

```text
Severity
Affected code
file:line
Failure scenario
Reasoning
Suggested remediation
```

BugRabbit can also run this review automatically in CI on every pull request or push.

---

## Install

```bash
claude plugin marketplace add vishnu-77/bug-fixer
claude plugin install bugrabbit@bugrabbit
```

For local development:

```bash
claude --plugin-dir <path-to-bugrabbit>
```

Then initialise a repository:

```text
/bugrabbit:init-repo <repo-path>
```

BugRabbit checks the repository, remote, host authentication, runtime, and index before starting work.

---

## Repository hosts

BugRabbit uses the repository host as the source of truth for issues and pull requests.

Currently supported:

* GitHub
* GitLab
* Bitbucket Cloud

One repository is active per BugRabbit session.

State is keyed by:

```text
owner/repository#issue
```

so `repo-a#12` and `repo-b#12` are always treated as separate work items.

---

## Commands

| Command                             | Purpose                                |
| ----------------------------------- | -------------------------------------- |
| `/bugrabbit:init-repo [path]`       | Initialise BugRabbit                   |
| `/bugrabbit:set-repo <path>`        | Switch the active repository           |
| `/bugrabbit:create-issue "<title>"` | Create a deduplicated issue            |
| `/bugrabbit:triage-issue <#>`       | Analyse an issue without changing code |
| `/bugrabbit:work-issue <#>`         | Reproduce and fix one issue            |
| `/bugrabbit:autofix-issues`         | Process multiple eligible issues       |
| `/bugrabbit:review-pr <#>`          | Review a pull request                  |
| `/bugrabbit:review-diff [ref]`      | Review local or committed changes      |
| `/bugrabbit:status`                 | Show current BugRabbit state           |
| `/bugrabbit:status-check`           | Detect state drift or duplication      |
| `/bugrabbit:findings`               | Manage review findings                 |
| `/bugrabbit:watch-issues`           | Poll or schedule issue tracking        |
| `/bugrabbit:adr <title>`            | Record an architecture decision        |

---

## The agents

BugRabbit coordinates four specialised Claude Code agents.

| Agent         | Role                                 |
| ------------- | ------------------------------------ |
| `bug-triager` | Reproduction and root-cause analysis |
| `bug-fixer`   | Minimal implementation               |
| `pr-reviewer` | Bug-focused code review              |
| `qa-verifier` | Regression and verification          |

The coordinator controls delegation, task state, and repository boundaries.

---

## Designed to fail safely

BugRabbit does not guess when it cannot establish the cause of a bug.

If reproduction fails or the root cause remains ambiguous, the issue becomes:

```text
BLOCKED
```

with a focused question explaining what information is missing.

No speculative patch is produced.

---

## What agents can do

BugRabbit agents can:

* inspect repository code
* reproduce failures
* modify code
* add regression tests
* run verification
* create commits
* create and push `fix/*` branches

They cannot:

* create pull requests
* merge pull requests
* push directly to `main` or `master`
* force-push
* rebase
* amend commits
* delete repositories or issues
* deploy code
* commit secrets

The integration boundary remains human-controlled.

---

## Permission guardrails

Claude Code plugins cannot currently distribute permission policy themselves.

BugRabbit therefore expects destructive operations to be denied in your Claude Code settings.

```json
{
  "permissions": {
    "deny": [
      "Bash(gh pr merge:*)",
      "Bash(gh pr create:*)",
      "Bash(git push --force:*)",
      "Bash(git push -f:*)",
      "Bash(git push origin main:*)",
      "Bash(git push origin master:*)",
      "Bash(git commit --amend:*)",
      "Bash(git rebase:*)",
      "Bash(gh repo delete:*)",
      "Bash(rm -rf:*)"
    ]
  }
}
```

BugRabbit independently applies additional checks through:

```text
scripts/ci-guard.sh
scripts/ci-pr-meta-check.sh
```

The permission layer and repository guards act as separate enforcement boundaries.

---

## CI review

BugRabbit can review every GitHub pull request and push using:

```text
bug-finder.yml
```

The workflow currently uses a self-hosted runner labelled:

```text
claude
```

with Claude Code authenticated on the runner.

No `ANTHROPIC_API_KEY` repository secret is required.

---

## A typical workflow

```text
/bugrabbit:init-repo ~/code/my-app

/bugrabbit:triage-issue 42

/bugrabbit:work-issue 42

/bugrabbit:review-diff main..fix/42-login-race

/bugrabbit:status
```

BugRabbit finishes with a verified branch such as:

```text
fix/42-login-race
```

You review it and open the pull request:

```bash
gh pr create --fill --base main --head fix/42-login-race
```

---

## Under the hood

For implementation and architecture details:

* [`WORKFLOW.md`](WORKFLOW.md) — day-to-day workflows and troubleshooting
* [`docs/agent-system-plan.md`](docs/agent-system-plan.md) — agent architecture and design
* [`CLAUDE.md`](CLAUDE.md) — coordinator operating rules
* [`CHANGELOG.md`](CHANGELOG.md) — release history

---

## Philosophy

Bug fixing should not mean giving an agent unrestricted control of a repository.

BugRabbit gives Claude Code enough autonomy to investigate, reproduce, repair, and verify a defect while keeping the irreversible integration decision outside the agent loop.

**Find the bug. Prove the bug. Fix the bug. Verify the fix. You merge it.**
