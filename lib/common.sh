#!/usr/bin/env bash
# shellcheck shell=bash
#
# Shared helpers for gh-uw. Sourced by the entrypoint and by each command
# script. Not executable on its own.
#
# Every function assumes `set -euo pipefail` is in effect in the caller.

# Exit with a message on stderr. Prefixed so the source is obvious when a
# command is buried in a script or CI log.
die() {
  printf 'gh uw: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'gh uw: %s\n' "$*" >&2
}

require_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 ||
    die "not inside a git repository"
}

# The ticket ID embedded in the current branch name.
#   feat/ABC-123-retry-webhooks -> ABC-123
# Prints nothing (and succeeds) when the branch has no ticket ID, so callers can
# decide whether that is fatal.
ticket_id() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null |
    grep -oE '[A-Z0-9]+-[0-9]+' |
    head -n 1 ||
    true
}

# Branch types we surface in PR titles. Extend this list to add more.
GH_UW_BRANCH_TYPES=${GH_UW_BRANCH_TYPES:-"HOTFIX RELEASE"}

# The branch type prefix, when the branch name starts with a marked one.
#   hotfix/ABC-123-oauth -> HOTFIX
#   release-2026.09      -> RELEASE
#   feat/ABC-123-oauth   -> (nothing)
# Always returns 0, so `x=$(branch_type)` is safe under `set -e` on a branch
# with no marked type.
branch_type() {
  local branch prefix type
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 0

  # Everything before the first / or -, uppercased. `${x^^}` would be neater
  # but needs bash 4; macOS still ships 3.2.
  prefix="${branch%%[/-]*}"
  prefix="$(printf '%s' "$prefix" | tr '[:lower:]' '[:upper:]')"

  for type in $GH_UW_BRANCH_TYPES; do
    if [[ $prefix == "$type" ]]; then
      printf '%s' "$type"
      return 0
    fi
  done
  return 0
}

# Subject line of the most recent commit, with any leading ticket prefix
# stripped so it is not duplicated when we add our own.
last_commit_subject() {
  git log -1 --pretty=%s 2>/dev/null |
    sed -E 's/^[A-Z0-9]+-[0-9]+:?[[:space:]]*//'
}

# `<command> <subcommand>` for every executable under commands/.
list_commands() {
  local group sub
  for group in "$GH_UW_ROOT"/commands/*/; do
    [[ -d $group ]] || continue
    for sub in "$group"*; do
      [[ -f $sub && -x $sub ]] || continue
      printf '  %s %s\n' "$(basename "$group")" "$(basename "$sub")"
    done
  done
}

list_subcommands() {
  local group_dir="$GH_UW_ROOT/commands/$1" sub
  printf 'USAGE\n  gh uw %s <subcommand> [flags]\n\nSUBCOMMANDS\n' "$1"
  for sub in "$group_dir"/*; do
    [[ -f $sub && -x $sub ]] || continue
    printf '  %s\n' "$(basename "$sub")"
  done
}
