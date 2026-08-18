#!/usr/bin/env sh
# gate-stats.sh — read a gate ledger and print the empirical numbers.
#
# It renders no judgment. It only counts what the SCRIPT emitted (the denominator) and what the
# HUMAN tagged (the outcomes). That split is the whole design: a number no one can forge, and a
# judgment no script can fake. See docs/learnings/empirical-test-plan.md §0–1.
#
# ── TAGS ARE MATCHED ON THEIR FIRST TWO CHARACTERS, AND THE ZERO THAT TAUGHT US WHY ──────────────
#
# The first parser compared outcome tags LITERALLY: `outcome["NO-GO/ok"]`. Then a three-week field
# ledger arrived (issue #10) in which the human's vocabulary was finer than two letters — `fp, bug`,
# `ok, besser GO`, `ok, manual fix` — and none of it was `ok` or `fp` to a string comparison. Twenty
# of fifty-two judged NO-GO rows fell out of the statistic, unannounced, and the output read
# "false-positive rate: 0%". The true value was 15%. The zero was not a measurement; it was a parser
# artifact, sitting in the very line meant to prove the gate trustworthy. So: the tag is the first
# two characters, the free text after a comma is the human's and is preserved — and any tag this
# parser cannot place is COUNTED AND PRINTED. A statistic that drops rows must say so.
#
#   exit 0  printed the numbers (or the report)
#   exit 2  no ledger to read — also under --report: never 0 with empty output
#
# Usage: sh gate-stats.sh [--report [--mark]] [path-to-ledger]
#          (default ledger: docs/architecture/gate-ledger.md)
#          --report        emit a dated, paste-ready markdown section instead of the plain numbers
#          --report --mark additionally APPEND a marker line to the ledger, so doctor.sh can count
#                          verdicts-since-last-report. An append, never an edit — append-only holds.

set -eu
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

LEDGER=""
REPORT=0
MARK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --report) REPORT=1 ;;
    --mark)   MARK=1 ;;
    -*)       echo "gate-stats: unknown option '$1'" >&2; exit 2 ;;
    *)        [ -n "$LEDGER" ] || LEDGER="$1" ;;
  esac
  shift
done
# Default is REPO-relative (see merge-gate.sh — the writer this reads; resolving from the cwd
# made a documented invocation report "no ledger" over a repo that had 28 rows, a false blank).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$LEDGER" ] || LEDGER="${REPO_ROOT:-.}/docs/architecture/gate-ledger.md"

# --mark exists to record that a REPORT was cut. Alone it would plant a marker for a report that
# never happened — doctor would then count from a lie. Refuse, do not guess.
if [ "$MARK" = 1 ] && [ "$REPORT" = 0 ]; then
  echo "gate-stats: --mark only makes sense together with --report (the marker records a report that was actually cut)" >&2
  exit 2
fi

[ -f "$LEDGER" ] || { echo "gate-stats: no ledger at $LEDGER" >&2; exit 2; }

[ "$REPORT" = 1 ] || echo "gate-stats: $LEDGER"

# A data row is a table line beginning with a UTC timestamp; the header/separator never match, and
# neither does a report-marker comment line. Columns are pipe-delimited:
# | when | PR | verdict | why | outcome |. awk trims each field.
awk -F'|' -v report="$REPORT" -v today="$(date -u +%Y-%m-%d 2>/dev/null || echo '?')" -v ledger="$LEDGER" '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  function pct(a, b) { return int(a * 100 / b + 0.5) }
  /^\| *[0-9][0-9][0-9][0-9]-/ {
    v = trim($4); w = trim($5); o = trim($6)
    total++
    verdict[v]++                       # exact key — a NO-GO must never count toward GO by substring
    d = substr(trim($2), 1, 10)
    if (first == "") first = d
    last = d

    # Exclusion IDs, position-independent: the why cell is reordered in NEW rows and preamble-first
    # in OLD ones, and a counter must not care which era a row is from.
    s = w
    while (match(s, /EX-[A-Z]+/)) { ex[substr(s, RSTART, RLENGTH)]++; s = substr(s, RSTART + RLENGTH) }

    # Mechanical cause classification of every NO-GO why cell. index(), not regex — these are
    # literal phrases the gate itself prints, parens and all. Precedence setup > checks > domain,
    # matching how the field report counted (a row failing on environment AND domain is an
    # environment problem first — the remedy the gate prints 55 times is "declare required checks").
    if (v == "NO-GO") {
      if (index(w, "declares no required status checks") || index(w, "no enforced approval") || \
          index(w, "no CI checks report") || index(w, "run wai-init before"))
                                                          cause_setup++
      else if (index(w, "required check(s) not green"))   cause_checks++
      else if (index(w, "touches an excluded domain"))    cause_domain++
      else                                                cause_other++
    }

    if (o == "") { untagged++; next }         # emitted, not yet judged by the human
    tagged++
    p = substr(o, 1, 2)                       # the tag is the FIRST TWO characters — see header
    if (p == "ok") {
      okc[v]++
      # `ok, besser GO` is the calibration signal: the block was correct by the rules, but the
      # human says GO would have been fine. Eleven of these sat unread in the field ledger while
      # the gate went unchanged for three weeks — the most precise feedback a gate can get.
      if (v == "NO-GO" && index(o, "ok, besser GO") == 1) besser++
    }
    else if (p == "fp") fpc[v]++
    else if (p == "fn") fnc[v]++
    else if (p == "ni") nilc[v]++             # nil: the verdict says nothing about the code
    else {
      unmatched++
      if (!(o in seen_um)) { seen_um[o] = 1; umlist = umlist (umlist == "" ? "" : ", ") o }
    }
  }
  END {
    nil_total   = nilc["GO"] + nilc["NO-GO"] + nilc["UNKNOWN"] + nilc["MOOT"]
    nogo_ok     = okc["NO-GO"] + 0; nogo_fp = fpc["NO-GO"] + 0
    nogo_judged = nogo_ok + nogo_fp
    go_judged   = okc["GO"] + fpc["GO"] + fnc["GO"]
    fn          = fnc["GO"] + 0               # fn is DEFINED on GO rows only (issue #10, finding 4)
    fn_misfiled = fnc["NO-GO"] + fnc["UNKNOWN"] + fnc["MOOT"]

    if (report) {
      # ── the paste-ready extract docs/open-questions.md asks field users for ────────────────────
      print "## Gate report — " today
      print ""
      print "Ledger: `" ledger "` · period covered: " (total ? first " → " last : "no rows yet")
      print ""
      printf "- verdicts: %d — GO %d · NO-GO %d · UNKNOWN %d · MOOT %d\n", \
             total, verdict["GO"] + 0, verdict["NO-GO"] + 0, verdict["UNKNOWN"] + 0, verdict["MOOT"] + 0
      printf "- outcome coverage: %d of %d tagged", tagged + 0, total
      if (total > 0) printf " (%d%%)", pct(tagged, total)
      printf " · %d untagged\n", untagged + 0
      if (unmatched > 0)
        printf "- %d unmatched tag(s): %s — these rows are in NO rate below\n", unmatched, umlist
      if (nil_total > 0)
        printf "- nil: %d — verdicts that said nothing about the code; excluded from fp/fn\n", nil_total
      if (nogo_judged > 0)
        printf "- false positives: %d of %d judged NO-GOs = %d%% (ok %d · fp %d)\n", \
               nogo_fp, nogo_judged, pct(nogo_fp, nogo_judged), nogo_ok, nogo_fp
      else
        print "- false positives: no judged NO-GOs yet"
      if (go_judged > 0)
        printf "- false negatives: %d of %d judged GO rows = %d%%\n", fn, go_judged, pct(fn, go_judged)
      else
        print "- false negatives: no judged GO rows yet"
      if (fn_misfiled > 0)
        printf "- data quality: %d fn tag(s) on NO-GO rows — fn is defined on GO rows only\n", fn_misfiled
      if (verdict["NO-GO"] > 0)
        printf "- NO-GO causes: setup %d · checks %d · domain %d · other %d (of %d NO-GO rows)\n", \
               cause_setup + 0, cause_checks + 0, cause_domain + 0, cause_other + 0, verdict["NO-GO"]
      if (nogo_judged > 0)
        printf "- calibration: %d of %d correct NO-GOs were marked %s by the human (%d of %d judged = %d%%)\n", \
               besser + 0, nogo_ok, "\047better GO\047", besser + 0, nogo_judged, pct(besser, nogo_judged)
      # Top exclusion reasons, most-cited first. Plain selection over a handful of tags — POSIX awk
      # has no sort, and this set is single digits wide by construction.
      exline = ""
      for (n = 1; n <= 5; n++) {
        best = ""
        for (t in ex) {
          if (t in used) continue
          if (best == "" || ex[t] > ex[best] || (ex[t] == ex[best] && t < best)) best = t
        }
        if (best == "") break
        used[best] = 1
        exline = exline (exline == "" ? "" : " · ") best " " ex[best]
      }
      if (exline != "") print "- top exclusion reasons: " exline
      exit
    }

    if (total == 0) { print "  no verdicts logged yet"; exit }

    printf "  %d verdict(s) the script demonstrably emitted", total
    print  "   ← Test 0: each is proof the gate RAN, not that memory was consulted"
    printf "     GO %d · NO-GO %d · UNKNOWN %d · MOOT %d\n", \
           verdict["GO"] + 0, verdict["NO-GO"] + 0, verdict["UNKNOWN"] + 0, verdict["MOOT"] + 0
    if (untagged > 0)
      printf "     %d still untagged — a ratio over untagged rows is not yet a ratio\n", untagged
    if (unmatched > 0)
      printf "     %d unmatched tag(s): %s — these rows are in NO ratio below; a statistic that drops rows must say so\n", \
             unmatched, umlist
    if (nil_total > 0)
      printf "     %d nil-tagged row(s) — the verdict said nothing about the code (e.g. CI still running); excluded from fp/fn\n", \
             nil_total
    print  ""

    # 1.1 — of the NO-GOs the human has judged, how many were merged unchanged anyway (gate too strict)?
    printf "  1.1  false-positive rate (NO-GO the gate got wrong):  "
    if (nogo_judged == 0) print "no judged NO-GOs yet"
    else printf "%d of %d judged NO-GOs = %d%%   (a cluster means CONTRACT_PATHS is too wide)\n", \
                nogo_fp, nogo_judged, pct(nogo_fp, nogo_judged)
    if (nogo_judged > 0)
      printf "       calibration: %d of %d correct NO-GOs were marked %s by the human (%d of %d judged = %d%%)\n", \
             besser + 0, nogo_ok, "\047better GO\047", besser + 0, nogo_judged, pct(besser, nogo_judged)

    # 1.2 — the one that matters: a GO that should have been blocked. No script can find this.
    printf "  1.2  FALSE NEGATIVES (a GO that should have blocked and did not):  %d\n", fn
    print  "       one of these outweighs ten false positives — it is the number that makes the case"
    if (fn == 0 && untagged > 0)
      print "       (still 0 — but do the weekly GO review before you read 0 as final)"
    if (fn_misfiled > 0)
      printf "       %d fn tag(s) on NO-GO rows — fn is defined on GO rows only; counted in NO headline above\n", \
             fn_misfiled

    if (verdict["NO-GO"] > 0) {
      printf "  NO-GO causes (mechanical read of each why cell):  setup %d · checks %d · domain %d · other %d\n", \
             cause_setup + 0, cause_checks + 0, cause_domain + 0, cause_other + 0
      print  "       setup = no required checks declared / no approval rule · checks = a required check not green · domain = excluded domain"
    }
  }
' "$LEDGER"

# --report --mark: plant the marker doctor.sh counts from. APPEND, never edit — the ledger's
# append-only rule covers this line exactly like a verdict row. The row count is re-derived with
# the same timestamp anchor the awk above keys on, two lines apart so they cannot drift unseen.
if [ "$MARK" = 1 ]; then
  ROWS="$(grep -cE '^\| *[0-9]{4}-' "$LEDGER" || true)"
  printf '<!-- report %s rows=%s -->\n' "$(date -u +%Y-%m-%d 2>/dev/null || echo '?')" "${ROWS:-0}" >> "$LEDGER" \
    || { echo "gate-stats: could not append the report marker to $LEDGER — the report above stands, the marker does not" >&2; exit 2; }
fi
