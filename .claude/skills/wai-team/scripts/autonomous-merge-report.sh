#!/usr/bin/env sh
# autonomous-merge-report.sh — reconstruct what an autonomous run actually merged, from RECORDS, not
# memory.
#
# The one thing an autonomous run must never do is TELL you what it merged. "The model remembers it
# merged #12, #14 and #17" is precisely the unauditable claim the whole suite is built to refuse —
# and the stakes are higher here than anywhere, because these merges happened with no human in the
# loop. So the report is reconstructed from two independent records that neither the model nor this
# script authored in the moment:
#
#   1. the append-only GATE LEDGER — every GO/NO-GO/UNKNOWN the merge gate emitted (written by the
#      gate SCRIPT, the denominator of the empirical phase); and
#   2. the GIT LOG of what landed on the base branch during the run (--first-parent, so each landing
#      is one commit).
#
# An autonomous merge is the INTERSECTION: a commit that landed on main during the run AND carries a
# recorded gate GO. Cross the two and the disagreements are the valuable part — a merge with NO
# recorded GO is surfaced LOUDLY (did it bypass the gate?), a GO with no merge is noted (armed,
# awaiting a human, or merged elsewhere). None of this is inferred; every line traces to a row in one
# of the two records.
#
# NEVER FABRICATE. If the gate ledger cannot be read, the report is not produced — an empty or
# guessed report would be worse than none, because it would read as "nothing merged autonomously"
# when the truth is "we do not know". That is exit 2. Withheld reasons are printed VERBATIM from the
# ledger's `why` cell; this script does not re-judge whether something was really a Blocker — that
# judgment was already made and recorded, and re-deriving it here would just be a second, weaker guess.
#
#   exit 0  report produced (including "nothing merged autonomously in this window" — a real answer)
#   exit 2  the gate ledger could not be read, or the required arguments are absent — UNKNOWN; the
#           report is NOT produced and the gap is stated. (If only the git log is unreadable, the
#           report degrades to a ledger-only view, clearly labelled as un-corroborated — still exit 0.)
#
# Usage: sh autonomous-merge-report.sh <gate-ledger> <git-log-range> <run-start-ts>
#   e.g. sh autonomous-merge-report.sh docs/architecture/gate-ledger.md "abc123..HEAD" 2026-08-02T12:00:00Z

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX word/glob semantics required

LEDGER="${1:-}"
RANGE="${2:-}"
START="${3:-}"
if [ -z "$LEDGER" ] || [ -z "$RANGE" ] || [ -z "$START" ]; then
  echo "autonomous-merge-report: need <gate-ledger> <git-log-range> <run-start-ts> (UNKNOWN)." >&2
  echo "  usage: sh autonomous-merge-report.sh <gate-ledger> <git-log-range> <run-start-ts>" >&2
  exit 2
fi

# The ledger is the load-bearing record. Unreadable ⇒ we do not know what merged ⇒ do not fabricate.
[ -f "$LEDGER" ] || { echo "autonomous-merge-report: cannot read the gate ledger at '$LEDGER' — cannot reconstruct the run (UNKNOWN)." >&2; exit 2; }

# The git log is corroboration. If it cannot be read, the report degrades rather than failing — but
# it must SAY it is un-corroborated, never quietly present the ledger's GO rows as confirmed merges.
GITOK=1
MERGES=""
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  MERGES="$(git log --first-parent --pretty=format:'%h%x09%s' "$RANGE" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || GITOK=0
else
  GITOK=0
fi

echo "autonomous-merge-report: ledger=$LEDGER  range=$RANGE  since=$START"
echo

# Two streams into one awk, separated by an FS control byte no subject or ledger cell contains:
# first the merge lines (hash <tab> subject), then the raw ledger. The separator is emitted by
# printf at runtime, so the script source holds no control character.
{ printf '%s\n' "$MERGES"; printf '\034\n'; cat "$LEDGER"; } | awk -v start="$START" -v gitok="$GITOK" -v range="$RANGE" '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  # PR number for a landing commit: prefer an explicit "pull request #N" (merge commit); otherwise
  # the LAST #N in the subject — the squash convention "title (#N)" puts the PR last, and an earlier
  # #N is usually an issue reference in the title, not the PR.
  function pr_of(s,   low, tok, t, last) {
    low = tolower(s)
    if (match(low, /pull request #[0-9]+/)) {
      tok = substr(low, RSTART, RLENGTH); match(tok, /#[0-9]+/); return substr(tok, RSTART + 1, RLENGTH - 1)
    }
    t = s; last = ""
    while (match(t, /#[0-9]+/)) { last = substr(t, RSTART + 1, RLENGTH - 1); t = substr(t, RSTART + RLENGTH) }
    return last
  }

  BEGIN { phase = 1; start16 = substr(start, 1, 16) }
  $0 == "\034" { phase = 2; next }

  phase == 1 {
    if ($0 == "") next
    ti = index($0, "\t"); if (ti == 0) next
    h = substr($0, 1, ti - 1); s = substr($0, ti + 1)
    mtotal++
    pr = pr_of(s)
    if (pr != "") {
      if (!(pr in mergepr)) { mergepr[pr] = s; mhash[pr] = h; morder[++mn] = pr }
    } else {
      noprc++; noprh[noprc] = h; nops[noprc] = s
    }
    next
  }

  phase == 2 {
    if ($0 !~ /^\| *[0-9][0-9][0-9][0-9]-/) next     # a data row starts with a UTC date in column 2
    split($0, b, "|")
    when = trim(b[2]); pr = trim(b[3]); verdict = trim(b[4]); why = trim(b[5])
    if (substr(when, 1, 16) < start16) next          # before the run — not ours
    if (verdict == "GO") {
      if (!(pr in gowhen)) { gowhen[pr] = when; goorder[++gn] = pr }
    } else if (verdict == "NO-GO" || verdict == "UNKNOWN") {
      heldn++; heldpr[heldn] = pr; heldv[heldn] = verdict; heldw[heldn] = why; heldt[heldn] = when
    }
    # MOOT rows (a review that ran after merge) are not a merge decision — ignored here.
  }

  END {
    if (gitok == "0") {
      print "  git log could not be read for range \"" range "\" — merges are NOT corroborated this run."
      print "  Showing the recorded gate GO verdicts since start; whether each actually merged is unverified."
      print ""
      print "### Gate GO since start (merge NOT corroborated — git range unreadable)"
      if (gn == 0) print "  (none)"
      else for (i = 1; i <= gn; i++) { pr = goorder[i]; print "  - PR #" pr " · GO @ " gowhen[pr] "   <- merge unverified" }
    } else {
      print "### Autonomously merged   (landed in the range AND carries a recorded gate GO)"
      c = 0
      for (i = 1; i <= mn; i++) { pr = morder[i]
        if (pr in gowhen) { c++; printf "  - PR #%s · merged %s \"%s\" · gate GO @ %s\n", pr, mhash[pr], mergepr[pr], gowhen[pr] }
      }
      if (c == 0) print "  (none)"

      print ""
      print "### Merged in range with NO recorded GO since start   (surface loudly — did this bypass the gate?)"
      c = 0
      for (i = 1; i <= mn; i++) { pr = morder[i]
        if (!(pr in gowhen)) { c++; printf "  - PR #%s · merged %s \"%s\"   <- no gate GO row since start\n", pr, mhash[pr], mergepr[pr] }
      }
      for (i = 1; i <= noprc; i++) { c++; printf "  - merge %s \"%s\"   <- no PR reference in the subject\n", noprh[i], nops[i] }
      if (c == 0) print "  (none)"

      print ""
      print "### Gate GO with no merge in this range   (armed and awaiting a human, or merged elsewhere)"
      c = 0
      for (i = 1; i <= gn; i++) { pr = goorder[i]
        if (!(pr in mergepr)) { c++; print "  - PR #" pr " · GO @ " gowhen[pr] }
      }
      if (c == 0) print "  (none)"
    }

    print ""
    print "### Withheld — held for you   (NO-GO / UNKNOWN since start; reasons VERBATIM from the ledger)"
    if (heldn == 0) print "  (none)"
    else for (i = 1; i <= heldn; i++) printf "  - PR #%s · %s @ %s · %s\n", heldpr[i], heldv[i], heldt[i], heldw[i]
  }
'

echo
echo "NOTE: every line above traces to the gate ledger or the git log — nothing is reconstructed from"
echo "      memory. A withheld reason is the recorded gate verdict, not a re-judgement. A 'merged with"
echo "      NO recorded GO' row is an anomaly worth a human's eyes, not proof of wrongdoing."
exit 0
