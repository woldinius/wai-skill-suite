#!/usr/bin/env sh
# ledger-locate.sh — the opt-in gate, as a lookup nobody has to remember to perform.
#
# THE LEDGER IS THE CONSENT. Learning mode is active for exactly one person: the one who has a
# personal ledger for this repo. No ledger anywhere → the skill must do NOTHING (plant no gap,
# install no hook, create nothing) so a colleague who never opted in stays untouched. That gate is
# load-bearing, and it has one invisible failure mode the skill's own prose warns about:
#
#   A slug is DERIVED (from the remote, or the folder), and derived things drift — the repo is
#   transferred to an org, renamed, forked; the folder is moved. A naive path check then finds no
#   ledger at the new slug and concludes "this human never opted in" — going silent, orphaning
#   their Leitner state, and by the very design of the gate NOBODY is told. So the gate is a
#   LOOKUP, not a path check: it also reads what each ledger RECORDS about the repo it belongs to
#   (its remote URL, its owner/repo) and matches on THAT, which does not drift.
#
# This is the single owner of that lookup. wai-team's post-run learning hand-off routes
# through it; it does not re-implement the consent check.
#
#   exit 0  a ledger claims this repo — its path is printed on stdout (and nothing else is)
#   exit 1  no ledger anywhere claims this repo — this human has not opted in (be silent)
#   exit 2  could not even resolve the repo (fail closed) — do not conclude "not opted in"
#
# What this does NOT decide: whether to offer to rename the folder on a moved-repo match, or to
# CREATE a ledger. It reports where consent lives; acting on it is the skill's (and the human's) job.
#
# Usage:  sh ledger-locate.sh [repo-root]        (default: .)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "ledger-locate: cannot cd to '$ROOT' — cannot resolve the repo." >&2; exit 2; }

LEARN="${HOME:-}/.claude/learning"

# --- This repo's stable identity ----------------------------------------------------------------
# The remote URL is the strongest stable identity: it survives a folder move and a fresh clone, and
# it is exactly what a ledger records. (gh's nameWithOwner is derivable from it, so we do not need
# gh here — deriving offline keeps this deterministic and network-free. The skill may still prefer
# gh when it writes a ledger; the LOOKUP only needs something stable to match on.)
REMOTE="$(git config --get remote.origin.url 2>/dev/null || true)"

OWNER=""; REPO=""; NWO=""; SLUG=""
if [ -n "$REMOTE" ]; then
  _u="${REMOTE%.git}"; _u="${_u%/}"
  REPO="${_u##*/}"                       # last path segment
  _rest="${_u%/*}"                       # everything before it
  OWNER="${_rest##*[:/]}"                # segment after the last ':' or '/'
  if [ -n "$OWNER" ] && [ -n "$REPO" ]; then
    NWO="$OWNER/$REPO"                   # nameWithOwner form the ledger records
    SLUG="$OWNER-$REPO"                  # the primary ledger-dir slug
  fi
fi

# Last-resort slug: the repo root's folder name — the PARENT of the common git dir, not the
# worktree path (a linked worktree would otherwise split the state) and not the bare `.git`.
FOLDER=""
_gcd="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -n "$_gcd" ]; then
  FOLDER="$(basename "$(dirname "$_gcd")")"
else
  FOLDER="$(basename "$(pwd)")"
fi

# --- 1. Direct path — the normal case -----------------------------------------------------------
# The primary slug is derived from the remote, so it does NOT change when the folder moves; a plain
# folder move is caught right here. Try the remote-derived slug first, then the folder name.
for _slug in "$SLUG" "$FOLDER"; do
  [ -n "$_slug" ] || continue
  _p="$LEARN/$_slug/ledger.md"
  if [ -f "$_p" ]; then
    printf '%s\n' "$_p"
    exit 0
  fi
done

# --- 2. Content lookup — the drift case ---------------------------------------------------------
# The remote itself changed (transfer/rename), so no slug resolves — but a ledger somewhere records
# the old remote or owner/repo. Glob is lexically sorted, so the pick is deterministic (slug order).
if [ -n "$REMOTE$NWO" ] && [ -d "$LEARN" ]; then
  for _f in "$LEARN"/*/ledger.md; do
    [ -f "$_f" ] || continue            # no-match glob stays literal; this guards it
    if { [ -n "$REMOTE" ] && grep -Fq "$REMOTE" "$_f" 2>/dev/null; } ||
       { [ -n "$NWO" ]    && grep -Fq "$NWO"    "$_f" 2>/dev/null; }; then
      echo "ledger-locate: matched by recorded identity, not by slug — this repo appears to have moved or been renamed." >&2
      echo "  The ledger dir is '$(basename "$(dirname "$_f")")'; the current slug is '${SLUG:-$FOLDER}'. The skill may offer to rename it." >&2
      printf '%s\n' "$_f"
      exit 0
    fi
  done
fi

# --- 3. In-repo fallback ------------------------------------------------------------------------
# `temp/learning/ledger.md` is the fallback the skill uses when ~/.claude is not writable (CI,
# containers). If it exists, this human opted in here.
if [ -f "temp/learning/ledger.md" ]; then
  printf '%s\n' "temp/learning/ledger.md"
  exit 0
fi

# --- Nothing claims this repo -------------------------------------------------------------------
echo "ledger-locate: no ledger claims this repo (searched ${LEARN:-<no HOME>}/*/ledger.md and temp/learning/) — this human has not opted in." >&2
exit 1
