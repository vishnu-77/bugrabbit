#!/usr/bin/env bash
# log-prompt.sh — append each user prompt VERBATIM to SESSION-PROMPTS.md, grouped by session.
#
# Wire as a Claude Code `UserPromptSubmit` hook in .claude/settings.local.json (see the .example).
# Contract: this hook must NEVER break a prompt — it always exits 0 and writes nothing to stdout
# (stdout from a UserPromptSubmit hook is injected into the model context). Reads the hook payload
# JSON on stdin: { "prompt": "...", "session_id": "...", ... }.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || exit 0
FILE="$REPO/SESSION-PROMPTS.md"

input="$(cat)" || exit 0
prompt="$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)" || exit 0
[ -z "$prompt" ] && exit 0
sid="$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)" || sid="unknown"

marker="<!-- session:${sid} -->"
{
  if [ ! -f "$FILE" ] || ! grep -qF "$marker" "$FILE" 2>/dev/null; then
    printf '\n## Session %s — %s\n%s\n' "$(date '+%Y-%m-%d %H:%M')" "$sid" "$marker"
  fi
  printf -- '\n---\n\n%s\n' "$prompt"
} >> "$FILE" 2>/dev/null

exit 0
