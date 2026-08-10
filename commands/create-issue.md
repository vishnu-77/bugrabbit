---
description: File an issue in the active repo (optionally labelled auto-fix), with dedup against open issues.
argument-hint: '"<title>" [--body <text>] [--autofix]'
---

Use the enclosing Git repository, or the `/set-repo` override; the active repo's host must be
authenticated (`${CLAUDE_PLUGIN_ROOT}/scripts/host.sh auth-status`). Create an issue from **$ARGUMENTS**.

1. Parse a `<title>` (required) and optional `--body`, `--label`, `--autofix` (adds the `auto-fix`
   label so the cron poller and `/autofix-issues` pick it up — GitHub and GitLab both support labels
   natively).
2. **Dedup pre-flight.** Search existing open issues for a near-duplicate title
   (`${CLAUDE_PLUGIN_ROOT}/scripts/host.sh issue-list --state open --search "<title>"`). If a strong match exists,
   **stop and show it** — do not file a duplicate; ask the user whether to proceed anyway.
3. Create it: `${CLAUDE_PLUGIN_ROOT}/scripts/host.sh issue-create --title "<title>" [--body ...] [--label auto-fix]`.
   Never put secrets in the title/body.
4. If `--autofix`, run `${CLAUDE_PLUGIN_ROOT}/scripts/poll-issues.sh` so the new issue is recorded `UNTRIAGED` in
   `docs/issue-log.md` immediately (keeps the ledger idempotent with the cron).
5. Print the new issue number + URL and the next step (`/triage-issue <#>` or `/work-issue <#>`).
