#!/usr/bin/env sh
# verify-arrival.sh — did the merge actually ARRIVE on the default branch?
#
# The forge's MERGED label is a statement about a PR, not about the default branch: a stacked PR
# whose base already merged and was deleted merges into nothing — CI green, gate GO, label purple,
# and origin/<default> never receives the commit. This script asks the one question no earlier
# stage asks: is <commit> reachable from a freshly fetched origin/<default>?
# Why: docs/rationale/verify-arrival.md — the two field incidents that bought this check.
#
# FAIL CLOSED. This is a verifier, so "could not verify" NEVER prints as arrived:
#
#   exit 0  ARRIVED — the commit is an ancestor of origin/<default>; "merged" may mean "done".
#   exit 1  LOST — the commit is NOT reachable from origin/<default>. The forge may still say
#           MERGED; the branches that DO contain it are listed. Hand this to the human.
#   exit 2  UNKNOWN — could not verify: no commit given, unresolvable commit, no default branch
#           resolvable (gh silent AND no origin/HEAD), or the fetch failed. Never "arrived".
#
# The default branch comes from gh (`gh repo view --json defaultBranchRef` — the forge's setting,
# the one `Closes #N` obeys), falling back to `git symbolic-ref refs/remotes/origin/HEAD`. It is
# FETCHED before the ancestry test: a stale remote-tracking ref answers about yesterday's
# repository (the same staleness rule as wai-team's post-merge-verify.sh, which proves the merged
# commit is in the tree it is about to test).
# No self-log: this is an extractor, not a skill run (run-log.sh's two-tier rule — Tier 1 is 1:1 script↔skill only).
#
# Usage: sh verify-arrival.sh <commit> [repo-root]    (default root: the repo enclosing the cwd)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX word/glob semantics required

unknown() {
  echo "verify-arrival: UNKNOWN — $1" >&2
  echo "VERDICT: could not verify — and that is never 'arrived' (fail closed)."
  exit 2
}

ARG="${1:-}"
[ -n "$ARG" ] || unknown "usage: sh verify-arrival.sh <commit> [repo-root] — no commit given"
[ $# -le 2 ] || unknown "usage: sh verify-arrival.sh <commit> [repo-root] — too many arguments"

command -v git >/dev/null 2>&1 || unknown "git is not installed"

# Default root = the enclosing git worktree, not the cwd (the same repo-not-cwd rule as run-log.sh
# and open-items.sh; merge-gate.sh carries the incident that forced it). An explicit argument wins.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
ROOT="${2:-$REPO_ROOT}"
[ -n "$ROOT" ] || unknown "not inside a git repository (and no repo-root argument given)"
cd "$ROOT" 2>/dev/null || unknown "cannot cd to '$ROOT'"
git rev-parse --git-dir >/dev/null 2>&1 || unknown "'$ROOT' is not a git repository"

# 1 · resolve the default branch: gh first, origin/HEAD second, neither → UNKNOWN.
DEF=""; HOW=""
if command -v gh >/dev/null 2>&1; then
  DEF="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null | head -1 || true)"
  [ -z "$DEF" ] || HOW="via gh"
fi
if [ -z "$DEF" ]; then
  DEF="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)"
  DEF="${DEF##*/}"
  [ -z "$DEF" ] || HOW="via origin/HEAD"
fi
[ -n "$DEF" ] || unknown "could not resolve the default branch (gh silent AND no origin/HEAD)"
echo "verify-arrival: default branch is $DEF ($HOW)"

# 2 · fetch it FRESH — a stale remote-tracking ref would answer about yesterday's repository.
git fetch -q origin "$DEF" 2>/dev/null \
  || unknown "could not fetch origin/$DEF — the ancestry test would run against a stale ref"
git rev-parse --verify --quiet "origin/$DEF^{commit}" >/dev/null 2>&1 \
  || unknown "origin/$DEF does not resolve after the fetch"

COMMIT="$(git rev-parse --verify --quiet "$ARG^{commit}" 2>/dev/null || true)"
[ -n "$COMMIT" ] || unknown "could not resolve '$ARG' to a commit"

# 3 · the one question: reachable from the freshly fetched default branch? merge-base returns 0 for
# yes and 1 for no; anything else is an error and must not be read as either answer.
git merge-base --is-ancestor "$COMMIT" "origin/$DEF" 2>/dev/null
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "ARRIVED: $ARG is on origin/$DEF"
  exit 0
elif [ "$rc" -eq 1 ]; then
  echo "LOST: $ARG is NOT reachable from origin/$DEF — the forge may say MERGED; the default branch never received it."
  CONTAIN="$(git branch -r --contains "$COMMIT" 2>/dev/null | sed 's/^[* ]*//' | grep -v '^$' || true)"
  if [ -n "$CONTAIN" ]; then
    echo "Branches that DO contain it:"
    printf '%s\n' "$CONTAIN" | sed 's/^/  · /'
  else
    echo "No remote branch contains it — it exists only locally, or on a branch already deleted."
  fi
  exit 1
else
  unknown "git merge-base --is-ancestor failed (exit $rc) — the ancestry could not be tested"
fi
