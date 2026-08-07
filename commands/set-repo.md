---
description: Optionally override the auto-detected Git repository used for this session.
argument-hint: <path-or-subproject>
---

Normally BugRabbit uses the enclosing Git repository automatically. Use this command only to set
the active target repo for this session to **$ARGUMENTS** when controlling a different repository.

1. Resolve the path. It must be a directory that **is a git repo** (`git -C <path> rev-parse
   --is-inside-work-tree`). If not a git repo → stop and tell the user to run `/init-repo <path>`.
2. Confirm a GitHub remote exists (`git -C <path> remote -v`). If none → warn: issue/PR commands
   (`/triage-issue`, `/fix-issue`, `/review-pr`) will be inert until a remote + `gh auth` are wired;
   `/review-diff` and `/init-repo` still work.
3. Confirm `gh` is available (`command -v gh`) and authed (`gh auth status`). Report if missing.
4. **Store the resolved absolute path as the session's active repo.** Every branch, commit, gate run,
   and agent dispatch this session operates on this tree only. Announce it.
5. If no override is set, commands resolve `git rev-parse --show-toplevel` from the current directory.
6. **Open-work audit.** If `gh` is authed, list open issues labelled `auto-fix` (`gh -C <path> issue
   list --label auto-fix --state open`) and any open `FIX-NNN` rows in `docs/backlog.md`. Print them
   so the user sees what is queued.
