#!/usr/bin/env sh
# retro-compliance.sh — the retro's denominator: did the period's work leave a trace?
#
# Issue #10, Part B, measured in the field: a skill left a trace ONLY if it filed something, so the
# record measured the side effects of work, not the work. The run log (issue #11) is the fix — one
# appended row per run — but the run log's own writers are split in two tiers, and the second tier
# is PROSE: a skill's SKILL.md says "log the run at hand-back", and nothing checks that the model
# obeyed. That is the suite's own prompt-contract weakness, pointed at itself. This script is the
# check: it crosses the three artifacts that exist independently of each other — the run log (what
# claims to have run), the gate ledger (what the gate demonstrably emitted) and `git log --merges`
# (what demonstrably landed) — and reports the share of merged PRs that carry a gate verdict, with
# every raw count printed beside the rate. A merged PR with no verdict row is a review that either
# never ran or ran without its script; the ledger cannot tell those apart, and this line is where
# that gap becomes visible instead of comfortable.
#
# ADR-0002, and the reason this script does not self-log: it EXTRACTS, it does not run a skill.
# run-log.sh's own header restricts self-logging to scripts whose script↔skill mapping marks a real
# run; an extractor row would attribute a measurement to a retrospective that may never be written.
# The wai-retro SKILL logs the retro run itself, once, at hand-back. And in the same split: this
# script counts; whether a missing trace is a broken prompt contract or a squash-merge artifact is
# a judgment, and it stays out of here.
#
#   exit 0  the extract was emitted — including named-empty lines for an empty period
#   exit 2  an input could not be read (run log, gate ledger, or no git history here), or misuse —
#           nothing was counted, so read nothing as compliant. There is deliberately no exit 1:
#           this script renders no verdict.
#
# Usage: sh retro-compliance.sh [--since YYYY-MM-DD] [repo-root]        (default root: .)
#        Default period: every row/commit dated on or after the gate ledger's LAST report marker
#        (the `<!-- report … -->` line gate-stats.sh --report --mark appends); with no marker, all
#        rows. $RUN_LOG and $MERGE_GATE_LEDGER override the file paths, exactly as they do for the
#        scripts that write those files.

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

SINCE=""
ROOT="."
while [ $# -gt 0 ]; do
  case "$1" in
    --since)   [ $# -ge 2 ] && [ -n "${2:-}" ] || { echo "retro-compliance: --since needs a date (YYYY-MM-DD)" >&2; exit 2; }
               SINCE="$2"; shift ;;
    --since=)  echo "retro-compliance: --since needs a date (YYYY-MM-DD) — an empty value must not silently become 'all rows'" >&2; exit 2 ;;
    --since=*) SINCE="${1#--since=}" ;;
    -*)        echo "retro-compliance: unknown option '$1' (usage: sh retro-compliance.sh [--since YYYY-MM-DD] [repo-root])" >&2; exit 2 ;;
    *)         ROOT="$1" ;;
  esac
  shift
done
case "$SINCE" in
  '') ;;
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) echo "retro-compliance: --since wants YYYY-MM-DD, got '$SINCE'" >&2; exit 2 ;;
esac
cd "$ROOT" 2>/dev/null || { echo "retro-compliance: cannot cd to '$ROOT'" >&2; exit 2; }

RLOG="${RUN_LOG:-docs/architecture/run-log.md}"
LEDGER="${MERGE_GATE_LEDGER:-docs/architecture/gate-ledger.md}"

# FAIL CLOSED, all inputs up front. A compliance share computed over two of its three sources is
# not a smaller measurement — it is a different one that reads like the real thing. "I could not
# look" must never print as a number.
MISSING=""
{ [ -f "$RLOG" ] && [ -r "$RLOG" ]; }     || MISSING="$MISSING $RLOG"
{ [ -f "$LEDGER" ] && [ -r "$LEDGER" ]; } || MISSING="$MISSING $LEDGER"
GIT_OK=no
command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1 && GIT_OK=yes
[ "$GIT_OK" = yes ] || MISSING="$MISSING git-history(not a git repository, or no git)"
if [ -n "$MISSING" ]; then
  echo "retro-compliance: could not read:$MISSING — nothing was counted; a share over a missing source would read like the real thing." >&2
  exit 2
fi

# The anchor. --since wins; otherwise the last report marker's date; otherwise everything.
ANCHOR="all recorded rows (no report marker, no --since)"
if [ -n "$SINCE" ]; then
  ANCHOR="--since $SINCE"
else
  MDATE="$(sed -n 's/^<!-- report \([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\).*/\1/p' "$LEDGER" | tail -1)"
  if [ -n "$MDATE" ]; then
    SINCE="$MDATE"
    ANCHOR="last report marker in $LEDGER ($SINCE)"
  fi
fi

echo "retro-compliance: $ROOT"
echo "  period: $ANCHOR"

# ── run-log rows in the period, per skill ────────────────────────────────────────────────────────
# Same row anchor as run-log.sh writes (a timestamped table line); the header never matches.
RLRAW="$(awk -F'|' -v since="$SINCE" '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  /^\| *[0-9][0-9][0-9][0-9]-/ {
    if (since != "" && substr(trim($2), 1, 10) < since) next
    n++; sk[trim($3)]++
  }
  END { print n + 0; for (s in sk) print sk[s] " " s }' "$RLOG")"
RLN="$(printf '%s\n' "$RLRAW" | head -1)"
if [ "$RLN" = 0 ]; then
  echo "  run-log rows: none — 0 rows in the period ($RLOG)"
else
  PERSKILL="$(printf '%s\n' "$RLRAW" | sed 1d | sort -rn | awk '{ s = s (s ? " · " : "") $2 " " $1 } END { print s }')"
  echo "  run-log rows: $RLN ($RLOG)"
  echo "    per skill: $PERSKILL"
fi

# ── gate-ledger verdicts in the period ───────────────────────────────────────────────────────────
# Same row anchor as gate-stats.sh — one parser convention for the ledger, everywhere. This block
# counts rows and collects PR numbers; every RATE about the ledger belongs to gate-stats.sh.
LRAW="$(awk -F'|' -v since="$SINCE" '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  /^\| *[0-9][0-9][0-9][0-9]-/ {
    if (since != "" && substr(trim($2), 1, 10) < since) next
    n++; v[trim($4)]++; pr = trim($3); if (pr != "") prs[pr] = 1
  }
  END {
    printf "%d %d %d %d %d\n", n + 0, v["GO"] + 0, v["NO-GO"] + 0, v["UNKNOWN"] + 0, v["MOOT"] + 0
    for (p in prs) print p
  }' "$LEDGER")"
LSUM="$(printf '%s\n' "$LRAW" | head -1)"
LN="${LSUM%% *}"
VPRS="$(printf '%s\n' "$LRAW" | sed 1d | sort -n)"
if [ "$LN" = 0 ]; then
  echo "  gate-ledger verdicts: none — 0 rows in the period ($LEDGER)"
else
  echo "$LSUM" | { read -r _t _go _nogo _unk _moot
    echo "  gate-ledger verdicts: $_t — GO $_go · NO-GO $_nogo · UNKNOWN $_unk · MOOT $_moot ($LEDGER)"; }
fi

# ── merged PRs in the period ─────────────────────────────────────────────────────────────────────
# TWO ENUMERATORS, AND THEY ARE DIFFERENT MEASUREMENTS. `git log --merges` reads merge COMMITS: a
# squash- or rebase-merged PR leaves none. That is offline and deterministic, and it was the only
# source — which inverted the metric's purpose on any repo that squash-merges. On this repo PRs
# #1–#6 were merge-committed and everything since #15 was squashed, so the live traced share (5/5 =
# 100%) covered only the era that PREDATES the metric, and the very gap that motivated it (#15/#16
# merged without gate verdicts) was invisible. A denominator that silently excludes the population
# it was built to measure is worse than no denominator. (#24)
#
# So: prefer `gh pr list --state merged` when gh is available and authenticated — it counts a
# squash merge exactly like a merge commit — and fall back to `git log --merges` otherwise, with
# the caveat intact. WHICH ENUMERATOR PRODUCED THE NUMBER IS PRINTED ON EVERY LINE THAT USES IT:
# the two count different things, and a reader who cannot tell them apart is reading one number as
# if it were the other. Fail closed to the git path and NAME the degradation — a gh that errors
# must never silently become "nothing landed".
MERGE_SRC="git log --merges"
MERGE_NOTE=""
MPRS=""; MN=0; MPN=0; NONUM=0

GH_OK=no
command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && GH_OK=yes

if [ "$GH_OK" = yes ]; then
  # --limit is generous but FINITE, and a cap you cannot see is the failure this file exists to
  # make visible — so the ceiling is detected and reported rather than asserted away. Hitting it
  # does not invalidate the run: it makes the denominator a FLOOR, and the line says so, because a
  # truncated denominator inflates the traced share (fewer merged PRs, same matches) in the
  # comfortable direction.
  GHLIMIT=200
  GHRAW="$(gh pr list --state merged --limit "$GHLIMIT" --json number,mergedAt \
             --jq '.[] | [(.number|tostring), (.mergedAt // "")] | join(" ")' 2>/dev/null)" && ghrc=0 || ghrc=$?
  GHN="$(printf '%s\n' "$GHRAW" | grep -c . || true)"
  if [ "$ghrc" -eq 0 ] && [ "${GHN:-0}" -ge "$GHLIMIT" ]; then
    MERGE_NOTE=" [gh returned $GHN = the --limit ceiling: older merged PRs in this period may be MISSING, so the denominator is a floor and the share below is an UPPER bound]"
  fi
  if [ "$ghrc" -ne 0 ]; then
    MERGE_NOTE=" [gh pr list FAILED — fell back to merge commits; squash merges are NOT counted here]"
  else
    MPRS="$(printf '%s\n' "$GHRAW" | awk -v since="$SINCE" '
      NF { if (since == "" || substr($2, 1, 10) >= since) print $1 }' | sort -n | uniq)"
    MPN="$(printf '%s\n' "$MPRS" | grep -c . || true)"
    MN="$MPN"; NONUM=0
    MERGE_SRC="gh pr list --state merged"
  fi
fi

if [ "$MERGE_SRC" = "git log --merges" ]; then
  [ "$GH_OK" = yes ] || MERGE_NOTE=" [gh unavailable — squash/rebase merges leave no merge commit and are NOT counted]"
  if [ -n "$SINCE" ]; then
    MERGELOG="$(git log --merges --since="$SINCE 00:00:00" --date=short --pretty=format:'%s' 2>/dev/null)" || MERGELOG=""
  else
    MERGELOG="$(git log --merges --date=short --pretty=format:'%s' 2>/dev/null)" || MERGELOG=""
  fi
  MN="$(printf '%s\n' "$MERGELOG" | grep -c . || true)"
  MPRS="$(printf '%s\n' "$MERGELOG" | sed -n 's/^Merge pull request #\([0-9][0-9]*\).*/\1/p' | sort -n | uniq)"
  MPN="$(printf '%s\n' "$MPRS" | grep -c . || true)"
  NONUM=$((MN - MPN))
fi

if [ "$MPN" = 0 ] && [ "$MN" = 0 ]; then
  echo "  merged PRs: none — 0 in the period (enumerator: $MERGE_SRC)$MERGE_NOTE"
elif [ "$MERGE_SRC" = "gh pr list --state merged" ]; then
  echo "  merged PRs: $MPN in the period (enumerator: $MERGE_SRC — counts squash and rebase merges)$MERGE_NOTE"
else
  echo "  merged PRs: $MN merge commit(s), $MPN with a readable PR number (enumerator: $MERGE_SRC)$MERGE_NOTE"
fi

# ── the traced share ─────────────────────────────────────────────────────────────────────────────
# Of the merged PRs whose number is readable, how many carry a gate verdict row in the period? The
# raw counts stand beside the rate (principle: every metric needs a counter-reader — a 0% that was
# really 15% once shipped inside the very line meant to prove trustworthiness).
if [ "$MPN" = 0 ]; then
  echo "  traced share: not derivable — 0 merged PRs with a readable number is an empty denominator, not 100% compliance (enumerator: $MERGE_SRC)$MERGE_NOTE"
else
  MATCHED="$({ printf '%s\n' "$VPRS"; echo '=='; printf '%s\n' "$MPRS"; } | awk '
    /^==$/ { second = 1; next }
    !second { if (NF) a[$1] = 1; next }
    NF && ($1 in a) { n++ }
    END { print n + 0 }')"
  PCT=$(((MATCHED * 200 + MPN) / (2 * MPN)))
  echo "  traced share: $MATCHED of $MPN merged PRs carry a gate verdict in the period = $PCT% (enumerator: $MERGE_SRC · raw: merged $MN · ledger rows $LN · run-log rows $RLN)"
  [ "$NONUM" -gt 0 ] && echo "    $NONUM merge commit(s) without a PR number in the subject are in NO rate above — a share that drops rows must say so"
fi

echo
echo "COUNTS ONLY (ADR-0002): whether a missing trace is a broken prompt contract, a squash merge,"
echo "or a review that ran without its script is a judgment — the retro narrates it, the human owns it."
exit 0
