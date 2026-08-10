---
description: Set up or run the cron that polls the tracker for new (unchecked) issues and tracks them.
argument-hint: "[run | setup <cron>] (default: run once)"
---

Manage the issue-watching cron for the enclosing Git repository or `/set-repo` override. The poller is idempotent and
dedups by `owner/repo#issue` into `docs/issue-log.md`.

- **`run`** (default) — run `${CLAUDE_PLUGIN_ROOT}/scripts/poll-issues.sh "$VP_ACTIVE_REPO"` once now. Report how
  many new issues were recorded and list them. No fixing — tracking only.
- **`setup <cron>`** — create a scheduled routine (via the `schedule` skill / CronCreate) that runs
  the poller on `<cron>` (e.g. `*/15 * * * *`). A scheduled routine runs outside this session, so
  **resolve `${CLAUDE_PLUGIN_ROOT}` to its current absolute path now and embed that literal path** in
  the routine definition — do not rely on the env var being set at cron execution time. The routine:
  1. runs `<resolved-plugin-root>/scripts/poll-issues.sh` against the active repo,
  2. records new open issues as `UNTRIAGED` in `docs/issue-log.md` (dedup by repository + issue),
  3. if new `auto-fix`-labelled issues appeared, notifies (PushNotification) with the count and asks
     whether to run `/autofix-issues` — it does **not** auto-fix without confirmation.
  Announce the routine id and schedule. `setup` requires the active repo's host to be authenticated
  (`${CLAUDE_PLUGIN_ROOT}/scripts/host.sh auth-status` — `gh` for GitHub, `BUGRABBIT_GL_TOKEN` for GitLab).

The cron only **tracks** live issues; fixing is always an explicit `/work-issue` or `/autofix-issues`.
