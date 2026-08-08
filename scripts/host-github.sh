#!/usr/bin/env bash
#
# host-github.sh — GitHub backend for scripts/host.sh. Invoked as:
#   host-github.sh <op> <owner/repo> <target-dir> [op-args...]
# Lift-and-shift of BugRabbit's original direct `gh` calls — behavior-identical to pre-adapter.
#
set -uo pipefail

OP="$1"; SLUG="$2"; TARGET="$3"; shift 3

need_gh() {
  command -v gh >/dev/null 2>&1 || { echo "FAIL: gh not installed" >&2; exit 2; }
}

case "$OP" in
  auth-status)
    need_gh
    gh auth status >/dev/null 2>&1 || { echo "FAIL: gh not authed (gh auth login)" >&2; exit 2; }
    echo "ok" ;;

  issue-view)
    need_gh
    gh issue view "$1" -R "$SLUG" --comments ;;

  issue-list)
    need_gh
    STATE="open"; LABEL=""; SEARCH=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --state) STATE="$2"; shift 2 ;;
        --label) LABEL="$2"; shift 2 ;;
        --search) SEARCH="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    ARGS=(-R "$SLUG" --state "$STATE" --json number,state,title --jq '.[] | "\(.number)\t\(.state)\t\(.title)"')
    [ -n "$LABEL" ] && ARGS=(-R "$SLUG" --state "$STATE" --label "$LABEL" --json number,state,title --jq '.[] | "\(.number)\t\(.state)\t\(.title)"')
    [ -n "$SEARCH" ] && ARGS+=(--search "$SEARCH")
    gh issue list "${ARGS[@]}" 2>/dev/null ;;

  issue-state)
    need_gh
    st="$(gh issue view "$1" -R "$SLUG" --json state --jq .state 2>/dev/null)" || {
      echo "FAIL: gh issue view $1" >&2; exit 2
    }
    case "$st" in OPEN) echo "open" ;; *) echo "closed" ;; esac ;;

  issue-create)
    need_gh
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
    ARGS=(-R "$SLUG" --title "$TITLE")
    [ -n "$BODY" ] && ARGS+=(--body "$BODY")
    [ -n "$LABEL" ] && ARGS+=(--label "$LABEL")
    gh issue create "${ARGS[@]}" ;;

  issue-label|pr-label)
    # GitHub PRs are issues under the hood, so both ops hit the same labels endpoint.
    need_gh
    NUM="$1"; shift
    LABELS=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --label) LABELS+=("$2"); shift 2 ;;
        *) shift ;;
      esac
    done
    [ "${#LABELS[@]}" -gt 0 ] || { echo "FAIL: at least one --label required" >&2; exit 2; }
    ARGS=(-X POST "repos/$SLUG/issues/$NUM/labels")
    for l in "${LABELS[@]}"; do ARGS+=(-f "labels[]=$l"); done
    # `gh api` on this endpoint auto-creates any label name that doesn't already exist in the repo.
    gh api "${ARGS[@]}" >/dev/null && echo "ok: labeled #$NUM with ${LABELS[*]}" ;;

  pr-diff)
    need_gh
    gh pr diff "$1" -R "$SLUG" ;;

  pr-view)
    need_gh
    gh pr view "$1" -R "$SLUG" ;;

  pr-list)
    need_gh
    STATE="open"
    [ "${1:-}" = "--state" ] && STATE="$2"
    gh pr list -R "$SLUG" --state "$STATE" --json number,state,title,headRefName \
      --jq '.[] | "\(.number)\t\(.state)\t\(.title)\t\(.headRefName)"' 2>/dev/null ;;

  pr-comment)
    need_gh
    NUM="$1"; shift
    BODYFILE=""
    [ "${1:-}" = "--body-file" ] && BODYFILE="$2"
    [ -n "$BODYFILE" ] || { echo "FAIL: --body-file required" >&2; exit 2; }
    gh pr comment "$NUM" -R "$SLUG" --body-file "$BODYFILE" ;;

  *)
    echo "FAIL: unsupported op '$OP' for github backend" >&2; exit 2 ;;
esac
