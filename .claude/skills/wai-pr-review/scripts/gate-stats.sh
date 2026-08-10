#!/usr/bin/env sh
# gate-stats.sh — read a gate ledger and print the empirical numbers.
#
# It renders no judgment. It only counts what the SCRIPT emitted (the denominator) and what the
# HUMAN tagged (the outcomes). That split is the whole design: a number no one can forge, and a
# judgment no script can fake. See docs/learnings/empirical-test-plan.md §0–1.
#
#   exit 0  printed the numbers
#   exit 2  no ledger to read
#
# Usage: sh gate-stats.sh [path-to-ledger]     (default: docs/architecture/gate-ledger.md)

set -eu
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

LEDGER="${1:-docs/architecture/gate-ledger.md}"
[ -f "$LEDGER" ] || { echo "gate-stats: no ledger at $LEDGER" >&2; exit 2; }

echo "gate-stats: $LEDGER"

# A data row is a table line beginning with a UTC timestamp; the header/separator never match.
# Columns are pipe-delimited: | when | PR | verdict | why | outcome |. awk trims each field.
awk -F'|' '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  /^\| *[0-9][0-9][0-9][0-9]-/ {
    v = trim($4); o = trim($6)
    total++
    verdict[v]++
    if (o == "") { untagged++; next }         # emitted, not yet judged by the human
    outcome[v "/" o]++
  }
  END {
    if (total == 0) { print "  no verdicts logged yet"; exit }

    printf "  %d verdict(s) the script demonstrably emitted", total
    print  "   ← Test 0: each is proof the gate RAN, not that memory was consulted"
    printf "     GO %d · NO-GO %d · UNKNOWN %d\n", verdict["GO"], verdict["NO-GO"], verdict["UNKNOWN"]
    if (untagged > 0)
      printf "     %d still untagged — a ratio over untagged rows is not yet a ratio\n", untagged
    print  ""

    # 1.1 — of the NO-GOs the human has judged, how many were merged unchanged anyway (gate too strict)?
    nogo_ok = outcome["NO-GO/ok"]; nogo_fp = outcome["NO-GO/fp"]
    nogo_judged = nogo_ok + nogo_fp
    printf "  1.1  false-positive rate (NO-GO the gate got wrong):  "
    if (nogo_judged == 0) print "no judged NO-GOs yet"
    else printf "%d of %d judged NO-GOs = %d%%   (a cluster means CONTRACT_PATHS is too wide)\n", \
                nogo_fp, nogo_judged, int(nogo_fp * 100 / nogo_judged + 0.5)

    # 1.2 — the one that matters: a GO that should have been blocked. No script can find this.
    fn = outcome["GO/fn"] + outcome["NO-GO/fn"] + outcome["UNKNOWN/fn"]
    printf "  1.2  FALSE NEGATIVES (a verdict that should have blocked and did not):  %d\n", fn
    print  "       one of these outweighs ten false positives — it is the number that makes the case"
    if (fn == 0 && untagged > 0)
      print "       (still 0 — but do the weekly GO review before you read 0 as final)"
  }
' "$LEDGER"
