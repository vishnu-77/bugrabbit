---
description: Bootstrap a target repo for the bug-fixing system — git/remote check, copy CI workflow, index for code discovery.
argument-hint: "[path-or-subproject]"
---

Bootstrap **$ARGUMENTS** (default: the enclosing Git repository) so the agent system can operate on it. This is a
one-time setup per target.

1. **Prerequisites report** (do not fail silently — print exactly what is missing and the fix):
   - `git` repo? If not, offer `git init` (ask before running).
   - GitHub remote? If not, print: add one with `git remote add origin <url>`.
   - `gh` installed + authed? If not, print: `brew install gh && gh auth login`.
   - CI runner: note that `bug-finder.yml` needs a **self-hosted runner with local Claude Code**
     (no `ANTHROPIC_API_KEY` secret).
2. **Install the complete CI runtime.** Run `${CLAUDE_PLUGIN_ROOT}/scripts/install-runtime.sh [target]`. With no
   target it installs into the current Git root. This
   installs the workflow plus its reviewer spec, rubric, and guard scripts. It never overwrites a
   differing file: show the diff and ask before rerunning with `--force`.
3. **Index for code discovery.** Run codebase-memory MCP `index_repository` on the target so
   `search_graph`/`trace_path`/`get_code_snippet` work. Confirm with `index_status`.
4. **Summarise.** Print a checklist: git ✓/✗, remote ✓/✗, gh ✓/✗, runtime installed ✓/✗, indexed ✓/✗,
   and the next command (`/status`; `/set-repo` is unnecessary for the current repository).

Read-only except: optional `git init` (ask first) and copying the workflow file. Never commits,
never pushes.
