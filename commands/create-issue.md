---
description: File a GitHub issue in the active repo (optionally labelled auto-fix), with dedup against open issues.
argument-hint: '"<title>" [--body <text>] [--autofix]'
---

Use the enclosing Git repository, or the `/set-repo` override; `gh` must be authenticated. Create a GitHub issue from **$ARGUMENTS**.

1. Parse a `<title>` (required) and optional `--body`, `--label`, `--autofix` (adds the `auto-fix`
   label so the cron poller and `/autofix-issues` pick it up).
2. **Dedup pre-flight.** Search existing open issues for a near-duplicate title
   (`gh issue list --state open --search "<title>"`). If a strong match exists, **stop and show it** —
   do not file a duplicate; ask the user whether to proceed anyway.
3. Create it: `gh issue create --title "<title>" [--body ...] [--label auto-fix]`. Never put secrets
   in the title/body.
4. If `--autofix`, run `${CLAUDE_PLUGIN_ROOT}/scripts/poll-issues.sh` so the new issue is recorded `UNTRIAGED` in
   `docs/issue-log.md` immediately (keeps the ledger idempotent with the cron).
5. Print the new issue number + URL and the next step (`/triage-issue <#>` or `/work-issue <#>`).
