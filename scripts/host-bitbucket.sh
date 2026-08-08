#!/usr/bin/env bash
#
# host-bitbucket.sh — Bitbucket Cloud backend for scripts/host.sh. Invoked as:
#   host-bitbucket.sh <op> <workspace/repo> <target-dir> [op-args...]
#
# Auth: BUGRABBIT_BB_USER + BUGRABBIT_BB_TOKEN (an Atlassian API token — see
# https://id.atlassian.com/manage-profile/security/api-tokens). Bitbucket Cloud has no
# `gh auth login`-equivalent OAuth flow, so this is env-var Basic auth, checked up front by every op.
#
set -uo pipefail

OP="$1"; SLUG="$2"; TARGET="$3"; shift 3
API="https://api.bitbucket.org/2.0/repositories/$SLUG"

need_auth() {
  command -v curl >/dev/null 2>&1 || { echo "FAIL: curl not installed" >&2; exit 2; }
  command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not installed" >&2; exit 2; }
  [ -n "${BUGRABBIT_BB_USER:-}" ] && [ -n "${BUGRABBIT_BB_TOKEN:-}" ] || {
    echo "FAIL: BUGRABBIT_BB_USER / BUGRABBIT_BB_TOKEN not set (Atlassian API token: https://id.atlassian.com/manage-profile/security/api-tokens)" >&2
    exit 2
  }
}

# bb_api METHOD URL [json-body] — prints the response body, fails loudly on non-2xx (404 gets a
# specific hint since Bitbucket repos ship with the Issues feature OFF by default).
bb_api() {
  local method="$1" url="$2" body="${3:-}"
  local args=(-sS -u "$BUGRABBIT_BB_USER:$BUGRABBIT_BB_TOKEN" -X "$method" -w '\n%{http_code}')
  [ -n "$body" ] && args+=(-H "Content-Type: application/json" -d "$body")
  local out code
  out="$(curl "${args[@]}" "$url")" || { echo "FAIL: curl request failed: $url" >&2; exit 2; }
  code="${out##*$'\n'}"
  out="${out%$'\n'*}"
  if [ "$code" -ge 400 ] 2>/dev/null; then
    if [ "$code" = "404" ]; then
      echo "FAIL: $method $url -> 404 (not found, or Issues is disabled in repo settings)" >&2
    else
      echo "FAIL: $method $url -> HTTP $code: $(echo "$out" | jq -r '.error.message // .' 2>/dev/null)" >&2
    fi
    exit 2
  fi
  echo "$out"
}

# Bitbucket issue states (new/open/resolved/on hold/invalid/duplicate/wontfix/closed) -> open/closed.
norm_issue_state() { case "$1" in new|open) echo open ;; *) echo closed ;; esac; }

case "$OP" in
  auth-status)
    need_auth
    bb_api GET "https://api.bitbucket.org/2.0/user" >/dev/null
    echo "ok" ;;

  issue-view)
    need_auth
    ISSUE="$(bb_api GET "$API/issues/$1")"
    echo "$ISSUE" | jq -r '"#\(.id) [\(.state)] \(.title)\n\n\(.content.raw // "")"'
    echo "-- comments --"
    bb_api GET "$API/issues/$1/comments?pagelen=50" \
      | jq -r '.values[] | "\(.user.display_name // "?"): \(.content.raw // "")"' 2>/dev/null || true ;;

  issue-list)
    need_auth
    STATE="open"; LABEL=""; SEARCH=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --state) STATE="$2"; shift 2 ;;
        --label) LABEL="$2"; shift 2 ;;
        --search) SEARCH="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$LABEL" ] && echo "note: Bitbucket issues have no label equivalent; ignoring --label $LABEL" >&2
    Q=""
    [ "$STATE" = "open" ] && Q='state="new" OR state="open"'
    if [ -n "$SEARCH" ]; then
      esc="${SEARCH//\"/\\\"}"
      Q="${Q:+($Q) AND }title~\"$esc\""
    fi
    # ponytail: first page only (pagelen=50); paginate via the response's "next" URL if a repo
    # regularly carries more than 50 open issues.
    URL="$API/issues?pagelen=50"
    [ -n "$Q" ] && URL="$URL&q=$(printf '%s' "$Q" | jq -sRr @uri)"
    bb_api GET "$URL" | jq -r '.values[] | "\(.id)\t\(.state)\t\(.title)"' ;;

  issue-state)
    need_auth
    st="$(bb_api GET "$API/issues/$1" | jq -r '.state')"
    norm_issue_state "$st" ;;

  issue-create)
    need_auth
    TITLE=""; BODY=""; LABEL=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --title) TITLE="$2"; shift 2 ;;
        --body) BODY="$2"; shift 2 ;;
        --label) LABEL="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$TITLE" ] || { echo "FAIL: --title required" >&2; exit 2; }
    [ -n "$LABEL" ] && echo "note: Bitbucket issues have no label equivalent; ignoring --label $LABEL" >&2
    PAYLOAD="$(jq -n --arg t "$TITLE" --arg b "$BODY" '{title:$t, content:{raw:$b}}')"
    bb_api POST "$API/issues" "$PAYLOAD" | jq -r '"created: #\(.id) \(.title)"' ;;

  issue-label|pr-label)
    # Bitbucket Cloud has no label concept for issues or PRs — accept and no-op, same pattern as
    # --label on issue-create/issue-list, so callers don't need a host-specific branch.
    NUM="${1:-}"; [ -n "$NUM" ] && shift
    LABELS=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --label) LABELS+=("$2"); shift 2 ;;
        *) shift ;;
      esac
    done
    echo "note: Bitbucket has no label equivalent for issues or PRs; ignoring ${LABELS[*]:-}" >&2
    echo "ok" ;;

  pr-diff)
    need_auth
    curl -sS -f -u "$BUGRABBIT_BB_USER:$BUGRABBIT_BB_TOKEN" "$API/pullrequests/$1/diff" || {
      echo "FAIL: GET $API/pullrequests/$1/diff" >&2; exit 2
    } ;;

  pr-view)
    need_auth
    bb_api GET "$API/pullrequests/$1" | jq -r '"#\(.id) [\(.state)] \(.title)\n\(.summary.raw // "")"' ;;

  pr-list)
    need_auth
    STATE="OPEN"
    [ "${1:-}" = "--state" ] && STATE="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
    bb_api GET "$API/pullrequests?state=$STATE&pagelen=50" \
      | jq -r '.values[] | "\(.id)\t\(.state)\t\(.title)\t\(.source.branch.name)"' ;;

  pr-comment)
    need_auth
    NUM="$1"; shift
    BODYFILE=""
    [ "${1:-}" = "--body-file" ] && BODYFILE="$2"
    [ -n "$BODYFILE" ] || { echo "FAIL: --body-file required" >&2; exit 2; }
    PAYLOAD="$(jq -n --rawfile b "$BODYFILE" '{content:{raw:$b}}')"
    bb_api POST "$API/pullrequests/$NUM/comments" "$PAYLOAD" >/dev/null
    echo "ok" ;;

  *)
    echo "FAIL: unsupported op '$OP' for bitbucket backend" >&2; exit 2 ;;
esac
