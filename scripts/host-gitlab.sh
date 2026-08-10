#!/usr/bin/env bash
#
# host-gitlab.sh — GitLab backend for scripts/host.sh. Invoked as:
#   host-gitlab.sh <op> <namespace/project> <target-dir> [op-args...]
#
# Auth: BUGRABBIT_GL_TOKEN (a GitLab personal or project access token with `api` scope — see
# https://docs.gitlab.com/user/profile/personal_access_tokens/). Sent as a PRIVATE-TOKEN header, no
# `glab auth login`-equivalent OAuth flow assumed (glab, GitLab's official CLI, could replace this
# backend later if a repo already has it set up — REST was chosen to match the GitHub backend's
# host.sh contract shape and avoid a second required CLI install).
#
set -uo pipefail

OP="$1"; SLUG="$2"; TARGET="$3"; shift 3

need_auth() {
  command -v curl >/dev/null 2>&1 || { echo "FAIL: curl not installed" >&2; exit 2; }
  command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not installed" >&2; exit 2; }
  [ -n "${BUGRABBIT_GL_TOKEN:-}" ] || {
    echo "FAIL: BUGRABBIT_GL_TOKEN not set (GitLab personal/project access token, 'api' scope: https://docs.gitlab.com/user/profile/personal_access_tokens/)" >&2
    exit 2
  }
}
need_auth   # every op needs curl+jq+token; check once, then build the project-scoped API base.
PROJECT="$(printf '%s' "$SLUG" | jq -sRr @uri)"   # namespace/project -> URL-encoded path, GitLab's project id
API="https://gitlab.com/api/v4/projects/$PROJECT"

# gl_api METHOD URL [json-body] — prints the response body, fails loudly on non-2xx.
gl_api() {
  local method="$1" url="$2" body="${3:-}"
  local args=(-sS -H "PRIVATE-TOKEN: $BUGRABBIT_GL_TOKEN" -X "$method" -w '\n%{http_code}')
  [ -n "$body" ] && args+=(-H "Content-Type: application/json" -d "$body")
  local out code
  out="$(curl "${args[@]}" "$url")" || { echo "FAIL: curl request failed: $url" >&2; exit 2; }
  code="${out##*$'\n'}"
  out="${out%$'\n'*}"
  if [ "$code" -ge 400 ] 2>/dev/null; then
    if [ "$code" = "404" ]; then
      echo "FAIL: $method $url -> 404 (not found, or the token lacks access to this project)" >&2
    else
      echo "FAIL: $method $url -> HTTP $code: $(echo "$out" | jq -r '.message // .' 2>/dev/null)" >&2
    fi
    exit 2
  fi
  echo "$out"
}

# GitLab issue states (opened/closed) -> open/closed. Merge request states (opened/merged/closed/
# locked) collapse the same way for our normalized open/closed contract.
norm_state() { case "$1" in opened) echo open ;; *) echo closed ;; esac; }

case "$OP" in
  auth-status)
    need_auth
    gl_api GET "https://gitlab.com/api/v4/user" >/dev/null
    echo "ok" ;;

  issue-view)
    need_auth
    ISSUE="$(gl_api GET "$API/issues/$1")"
    echo "$ISSUE" | jq -r '"#\(.iid) [\(.state)] \(.title)\n\n\(.description // "")"'
    echo "-- comments --"
    gl_api GET "$API/issues/$1/notes?per_page=50" \
      | jq -r '.[] | "\(.author.name // "?"): \(.body)"' 2>/dev/null || true ;;

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
    # ponytail: first page only (per_page=50); paginate via the Link header if a project regularly
    # carries more than 50 matching issues.
    URL="$API/issues?per_page=50"
    [ "$STATE" = "open" ] && URL="$URL&state=opened"
    [ -n "$LABEL" ] && URL="$URL&labels=$(printf '%s' "$LABEL" | jq -sRr @uri)"
    [ -n "$SEARCH" ] && URL="$URL&search=$(printf '%s' "$SEARCH" | jq -sRr @uri)"
    gl_api GET "$URL" | jq -r '.[] | "\(.iid)\t\(.state)\t\(.title)"' ;;

  issue-state)
    need_auth
    st="$(gl_api GET "$API/issues/$1" | jq -r '.state')"
    norm_state "$st" ;;

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
    PAYLOAD="$(jq -n --arg t "$TITLE" --arg b "$BODY" --arg l "$LABEL" \
      '{title:$t, description:$b} + (if $l != "" then {labels:$l} else {} end)')"
    gl_api POST "$API/issues" "$PAYLOAD" | jq -r '"created: #\(.iid) \(.title)"' ;;

  issue-label)
    need_auth
    NUM="$1"; shift
    LABELS=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --label) LABELS+=("$2"); shift 2 ;;
        *) shift ;;
      esac
    done
    [ "${#LABELS[@]}" -gt 0 ] || { echo "FAIL: at least one --label required" >&2; exit 2; }
    JOINED="$(IFS=,; echo "${LABELS[*]}")"
    # GitLab's add_labels creates any label name not already present in the project.
    PAYLOAD="$(jq -n --arg l "$JOINED" '{add_labels:$l}')"
    gl_api PUT "$API/issues/$NUM" "$PAYLOAD" >/dev/null
    echo "ok: labeled #$NUM with $JOINED" ;;

  pr-label)
    need_auth
    NUM="$1"; shift
    LABELS=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --label) LABELS+=("$2"); shift 2 ;;
        *) shift ;;
      esac
    done
    [ "${#LABELS[@]}" -gt 0 ] || { echo "FAIL: at least one --label required" >&2; exit 2; }
    JOINED="$(IFS=,; echo "${LABELS[*]}")"
    PAYLOAD="$(jq -n --arg l "$JOINED" '{add_labels:$l}')"
    gl_api PUT "$API/merge_requests/$NUM" "$PAYLOAD" >/dev/null
    echo "ok: labeled #$NUM with $JOINED" ;;

  pr-diff)
    need_auth
    # GitLab content-negotiates a raw unified diff via a .diff suffix on the MR endpoint.
    curl -sS -f -H "PRIVATE-TOKEN: $BUGRABBIT_GL_TOKEN" "$API/merge_requests/$1.diff" || {
      echo "FAIL: GET $API/merge_requests/$1.diff" >&2; exit 2
    } ;;

  pr-view)
    need_auth
    gl_api GET "$API/merge_requests/$1" | jq -r '"#\(.iid) [\(.state)] \(.title)\n\(.description // "")"' ;;

  pr-list)
    need_auth
    STATE="opened"
    [ "${1:-}" = "--state" ] && { [ "$2" = "open" ] && STATE="opened" || STATE="$2"; }
    gl_api GET "$API/merge_requests?state=$STATE&per_page=50" \
      | jq -r '.[] | "\(.iid)\t\(.state)\t\(.title)\t\(.source_branch)"' ;;

  pr-comment)
    need_auth
    NUM="$1"; shift
    BODYFILE=""
    [ "${1:-}" = "--body-file" ] && BODYFILE="$2"
    [ -n "$BODYFILE" ] || { echo "FAIL: --body-file required" >&2; exit 2; }
    PAYLOAD="$(jq -n --rawfile b "$BODYFILE" '{body:$b}')"
    gl_api POST "$API/merge_requests/$NUM/notes" "$PAYLOAD" >/dev/null
    echo "ok" ;;

  *)
    echo "FAIL: unsupported op '$OP' for gitlab backend" >&2; exit 2 ;;
esac
