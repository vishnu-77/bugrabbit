---
description: Bootstrap a target repo for the bug-fixing system — git/remote check, copy CI workflow, index for code discovery.
argument-hint: "[path-or-subproject]"
---

Bootstrap **$ARGUMENTS** (default: the enclosing Git repository) so the agent system can operate on it. This is a
one-time setup per target.

1. **Prerequisites report** (do not fail silently — print exactly what is missing and the fix):
   - `git` repo? If not, offer `git init` (ask before running).
   - Remote present + host recognised? Run `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh detect`. If `unknown`, print: add a
     GitHub, Bitbucket Cloud, or GitLab origin remote (`git remote add origin <url>`), or set
     `VP_HOST` to override detection for an Enterprise/Server/self-hosted domain.
   - Host authed? Branch on the detected host:
     - `github` → `gh` installed + authed? If not, print: `brew install gh && gh auth login`.
     - `bitbucket` → `BUGRABBIT_BB_USER`/`BUGRABBIT_BB_TOKEN` set? If not, print: create an Atlassian
       API token (https://id.atlassian.com/manage-profile/security/api-tokens) and export both env vars.
     - `gitlab` → `BUGRABBIT_GL_TOKEN` set? If not, print: create a personal/project access token
       with `api` scope (https://docs.gitlab.com/user/profile/personal_access_tokens/) and export it.
     - `unknown` → note that issue/PR automation stays inert on this host, but git-mechanics-only
       commands (`/review-diff`, this bootstrap) still work.
   - CI runner: on `github`/`bitbucket`, note that the CI template needs a **self-hosted runner with
     local Claude Code** (no `ANTHROPIC_API_KEY` secret) — labelled `claude` for GitHub Actions, or
     registered with the `claude` label for Bitbucket Pipelines. On `gitlab`, note there is no CI
     template yet — the workflow-file install step below is skipped.
2. **Install the complete CI runtime.** Run `${CLAUDE_PLUGIN_ROOT}/scripts/install-runtime.sh [target]`. With no
   target it installs into the current Git root. This installs the reviewer spec, rubric, adapter
   scripts (`host.sh` + the matching `host-<host>.sh` backend), and guard scripts always, plus a CI
   template matching the detected host — `bug-finder.yml` (GitHub Actions) or `bitbucket-pipelines.yml`
   (Bitbucket Pipelines); skipped with a warning on GitLab (no template yet). It never overwrites a
   differing file: show the diff and ask before rerunning with `--force`. It also runs a one-off
   baseline `gate.sh` pass and prints whatever pre-existing lint/test/build gaps it finds — this is
   informational only (never blocks install) but means toolchain breakage (missing lint config,
   broken test runner, a monorepo `gate.sh` can't resolve into) is known up front, not discovered
   mid-fix on the first `/work-issue`.
3. **Index for code discovery.** Run codebase-memory MCP `index_repository` on the target so
   `search_graph`/`trace_path`/`get_code_snippet` work. Confirm with `index_status`. If the MCP
   server isn't connected in this environment, note that plainly and move on — agents fall back to
   Grep/Read/Glob without it, this just means the fast path isn't available.
4. **Summarise.** Print a checklist: git ✓/✗, remote ✓/✗, host detected + authed ✓/✗, runtime
   installed ✓/✗, indexed ✓/✗, baseline toolchain health (clean / N pre-existing gaps, from step 2),
   and the next command (`/status`; `/set-repo` is unnecessary for the current repository).

Read-only except: optional `git init` (ask first) and copying the workflow file. Never commits,
never pushes.
