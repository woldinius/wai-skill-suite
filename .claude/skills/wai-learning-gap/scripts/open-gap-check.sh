#!/usr/bin/env sh
# open-gap-check.sh — at most ONE open gap, checked on BOTH sides in one call.
#
# The invariant is "never plant a second gap while one is open". It has to be checked on two sides,
# and the skill's prose says why the ledger alone is not enough:
#
#   The ledger is a single unlocked file shared across every clone and worktree of a repo. Two
#   concurrent sessions both read "no open row" and both plant — so the working TREE (`git grep`
#   for the gap marker) is the side that actually catches a second gap, and the ledger is the
#   side that catches a marker a human deleted without solving. You need both.
#
# WHY THE EXIT CODE IS 0/1/2 AND NOT A BITMASK. A tempting design folds "which side" into the exit
# code (2 = ledger-side open). That is exactly the bug the merge gate exists to warn about: it
# steals the UNKNOWN code — the suite's universal "could not verify, fail closed" — and makes the
# gate misreport which of its own states it is in. So the SIDE goes in stdout, where it is data,
# and 2 keeps its one meaning: something could not be read.
#
#   exit 0  no gap is open on either side — it is safe to plant
#   exit 1  a gap IS open — stdout names WHICH side (this tree, ANOTHER worktree, and/or ledger);
#           resolve it first (flow B/C — a marker in another worktree is misplaced, not expired)
#   exit 2  a tree or the ledger could not be read (UNKNOWN) — fail closed, do not plant
#
# What this does NOT decide: anything judgmental — only whether an open gap exists, and where.
#
# A MARKER DETECTOR MUST NOT CONTAIN ITS OWN MARKER. This script used to grep for the literal
# string, which meant the literal was IN this file — so it matched itself, and it matched every
# other file that handles the marker as data (the hook installer, the test fixtures). Since
# `.claude/skills/**` is committed in every repo install.sh has touched, the result was that
# learning mode could NEVER plant a gap in a repo that vendors the suite: exit 1, "resolve the open
# gap first", and nothing to resolve. Assembling the pattern at run time is the fix that needs no
# path exclusions — and a blanket `:!.claude/skills/*` would have been wrong anyway, because this
# repo is itself a project someone may legitimately be learning on.
MARKER_WORD='LEARN'
MARKER="$MARKER_WORD #"
#
# THE TREE SIDE SWEEPS EVERY WORKTREE, NOT JUST ITS OWN. The ledger hangs off the repo and is
# shared across all worktrees; a working tree is not. This script used to grep only the tree it ran
# in, so the two sides it compares had different reach — and in the field (issue #13) that cost two
# days: a gap planted from a linked worktree was invisible in the main checkout, the check reported
# only the ledger row, and flow B's "no marker + no claim = expired" booked an exercise the human
# had never seen. "No marker HERE" and "no marker ANYWHERE" are different facts. So the sweep walks
# `git worktree list --porcelain`; a marker found in ANOTHER tree is reported as misplaced (exit 1,
# its own line), and a listed tree that cannot be read makes the verdict UNKNOWN (exit 2) — an
# unswept tree is never silently counted as clear.
#
# Usage:  sh open-gap-check.sh [ledger-path]
#   With no argument the ledger is located the same way the skill locates it — via
#   ledger-locate.sh — NOT by guessing one path. Guessing the `temp/` fallback meant that for a
#   normal participant (whose ledger is under ~/.claude/learning/) the ledger side was skipped
#   entirely while the output still announced "tree and ledger both clear". A green that names a
#   side it never read is the exact thing ADR-0002 forbids.

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

LEDGER="${1:-}"
LEDGER_SOURCE="given"
if [ -z "$LEDGER" ]; then
  LOCATE="$(dirname "$0")/ledger-locate.sh"
  if [ -x "$LOCATE" ] || [ -f "$LOCATE" ]; then
    LEDGER="$(sh "$LOCATE" 2>/dev/null)" && LEDGER_SOURCE="located" || _lrc=$?
    case "${_lrc:-0}" in
      0) : ;;
      1) LEDGER=""; LEDGER_SOURCE="none" ;;   # nobody has opted in — a true clear on this side
      *) LEDGER=""; LEDGER_SOURCE="unresolved" ;;
    esac
  else
    LEDGER_SOURCE="unresolved"
  fi
fi

UNKNOWN=""          # non-empty ⇒ a side could not be read
OPEN_TREE=""        # non-empty ⇒ THIS working tree carries a marker
OPEN_OTHER=""       # non-empty ⇒ ANOTHER worktree carries a marker (pre-formatted report lines)
OPEN_LEDGER=""      # non-empty ⇒ the ledger has an open row

# --- Tree side — the concurrency-safe one -------------------------------------------------------
# `git grep` exit codes: 0 = matches, 1 = no match, >=2 = error (e.g. not a git repo). Only a real
# error is UNKNOWN; "no match" is a clean clear, not a failure.
if command -v git >/dev/null 2>&1; then
  TREE_HITS="$(git grep -I -l -e "$MARKER" -- . ':!*.md' ':!*.mdx' ':!*.markdown' 2>/dev/null)"; _grc=$?
  if [ "$_grc" -gt 1 ]; then
    UNKNOWN="$UNKNOWN tree"
  elif [ -n "$TREE_HITS" ]; then
    OPEN_TREE="$TREE_HITS"
  fi

  # --- Worktree sweep — every OTHER tree of this repo ---------------------------------------------
  # Only in a repo we could read at all. Own-tree hits are reported above with their file list; a
  # hit in another tree is a different fact and gets a different sentence — flow B must treat it as
  # misplaced, never as expired.
  if [ "$_grc" -le 1 ]; then
    OWN_TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || OWN_TOP=""
    OWN_TOP_P="$(cd "${OWN_TOP:-.}" 2>/dev/null && pwd -P)" || OWN_TOP_P="$OWN_TOP"
    WT_LIST="$(git worktree list --porcelain 2>/dev/null)" || WT_LIST=""
    if [ -z "$WT_LIST" ]; then
      # A repo whose worktree list cannot even be enumerated is a tree side we cannot vouch for.
      echo "open-gap-check: git worktree list failed — the sweep across worktrees is incomplete." >&2
      UNKNOWN="$UNKNOWN worktrees"
    else
      _wt=""; _bare=""
      while IFS= read -r _wl; do
        case "$_wl" in
          "worktree "*) _wt="${_wl#worktree }" ;;
          bare)         _bare=1 ;;
          "")
            if [ -n "$_wt" ] && [ -z "$_bare" ]; then
              _wtp="$(cd "$_wt" 2>/dev/null && pwd -P)" || _wtp=""
              if [ -z "$_wtp" ]; then
                # Listed but unreadable (pruned dir, permissions): an unswept tree is UNKNOWN,
                # never a silent clear — the sweep must not quietly narrow to what it could reach.
                echo "open-gap-check: worktree $_wt is listed but cannot be read — sweep incomplete." >&2
                case "$UNKNOWN" in *worktrees*) : ;; *) UNKNOWN="$UNKNOWN worktrees" ;; esac
              elif [ "$_wtp" != "$OWN_TOP_P" ]; then
                git -C "$_wtp" grep -I -q -e "$MARKER" -- . ':!*.md' ':!*.mdx' ':!*.markdown' 2>/dev/null; _orc=$?
                if [ "$_orc" -eq 0 ]; then
                  OPEN_OTHER="${OPEN_OTHER}open gap: marker in ANOTHER worktree: $_wtp — misplaced, not expired
"
                elif [ "$_orc" -gt 1 ]; then
                  echo "open-gap-check: worktree $_wtp could not be searched — sweep incomplete." >&2
                  case "$UNKNOWN" in *worktrees*) : ;; *) UNKNOWN="$UNKNOWN worktrees" ;; esac
                fi
              fi
            fi
            _wt=""; _bare="" ;;
        esac
      done <<EOF
$WT_LIST

EOF
    fi
  fi
else
  UNKNOWN="$UNKNOWN tree"
fi

# --- Ledger side --------------------------------------------------------------------------------
# A ledger `open` status is a table cell that is exactly `open`. `solved`, `expired`, `solved-with-
# hint`, `resolved (Claude)` do not contain it as a standalone cell, so the `| open |` anchor is
# precise. No ledger path at all is a true clear on this side (there is no open row if there is no
# ledger); a path we were TOLD to read but cannot is UNKNOWN.
if [ -n "$LEDGER" ]; then
  if [ -f "$LEDGER" ] && [ -r "$LEDGER" ]; then
    if grep -Eq '\|[[:space:]]*open[[:space:]]*\|' "$LEDGER" 2>/dev/null; then
      OPEN_LEDGER="$(grep -En '\|[[:space:]]*open[[:space:]]*\|' "$LEDGER" 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"
    fi
  else
    UNKNOWN="$UNKNOWN ledger"
  fi
elif [ "$LEDGER_SOURCE" = "unresolved" ]; then
  # We could not even determine WHERE the ledger is. That is not "no ledger" — it is not knowing,
  # and the two must never print the same sentence.
  UNKNOWN="$UNKNOWN ledger"
fi

# --- Verdict ------------------------------------------------------------------------------------
# A DEFINITE open gap is the strongest actionable fact, so it wins over an unreadable other side:
# either way you must not plant, but "resolve the open gap" (1) is more useful than "I could not
# check" (2). Only when nothing is definitely open AND a side was unreadable do we return UNKNOWN.
if [ -n "$OPEN_TREE" ] || [ -n "$OPEN_OTHER" ] || [ -n "$OPEN_LEDGER" ]; then
  [ -n "$OPEN_TREE" ]   && echo "open gap: tree — marker in $(printf '%s' "$OPEN_TREE" | tr '\n' ' ')"
  [ -n "$OPEN_OTHER" ]  && printf '%s' "$OPEN_OTHER"
  [ -n "$OPEN_LEDGER" ] && echo "open gap: ledger — open row(s) at line(s) $OPEN_LEDGER of $LEDGER"
  echo "open-gap-check: an open gap exists — resolve it (flow B or C) before planting another."
  exit 1
fi

if [ -n "$UNKNOWN" ]; then
  echo "open-gap-check: could not read:$UNKNOWN — cannot confirm the tree/ledger is clear (UNKNOWN)." >&2
  exit 2
fi

# Say exactly which sides were read. "Both clear" when one side was never located is the claim this
# script was caught making.
case "$LEDGER_SOURCE" in
  none) echo "open-gap-check: tree clear; no ledger claims this repo (nobody opted in) — safe to plant." ;;
  *)    echo "open-gap-check: no open gap on either side (tree clear, ledger $LEDGER clear) — safe to plant." ;;
esac
exit 0
