#!/usr/bin/env sh
# ledger-lint.sh — the third operation on the personal ledger.
#
# A ledger has ingest (the skill WRITES rows) and query (it READS boxes to choose a gap); this is
# the lint. It checks: every axis label is in the enum, an enabled axis carries a level, at most
# ONE gap is open, and a Socratic gap records its expected answer. The last is load-bearing: a
# Socratic gap stays GREEN (it removes no code), so its ONLY proof of a solve is the comparison
# against the recorded expected answer — without one the gap can never be closed.
# Why: docs/rationale/ledger-lint.md § The same hole catalog-lint closed, one level down
#
# IT NEVER REWRITES A LEDGER. An existing ledger belongs to the human — including a human-authored
# one whose shape differs from the template (different section names, another language). This lint
# validates the shape it recognises and SKIPS the rest with a ⚠, reporting only. It is the exact
# line catalog-lint holds: a checker that renders a verdict it cannot justify gets switched off.
#
#   exit 0  consistent — or a divergent ledger it correctly declined to lint
#   exit 1  a check failed — the row and the repair are printed
#   exit 2  the ledger could not be read at all
#
# What this does NOT decide: whether an axis label is semantically RIGHT for the topic (enum only),
# or anything about pedagogy. It never auto-fixes.
#
# Usage:  sh ledger-lint.sh [ledger-path]        (default: temp/learning/ledger.md)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

LEDGER="${1:-temp/learning/ledger.md}"
[ -f "$LEDGER" ] && [ -r "$LEDGER" ] || { echo "ledger-lint: no readable ledger at $LEDGER" >&2; exit 2; }

echo "ledger-lint: $LEDGER"

# The whole validator is one awk pass over the ledger. It tracks the current `## ` section, maps a
# recognised table's columns by their HEADER names (so a reordered column still resolves), and
# checks each data row. It contains no single quote (the program is single-quoted in the shell) —
# offending labels are shown in [brackets], never in quotes.
awk '
  function trim(s){ gsub(/^[ \t]+|[ \t]+$/,"",s); return s }
  function isrow(l){ return (l ~ /^\|/ && l !~ /^\|[ \t]*:?-+/) }

  /^## / {
    sec = ""
    if ($0 ~ /Learning axes/) sec = "axes"
    else if ($0 ~ /Gap log/)  sec = "gaps"
    hdr = 0; ai = ei = li = sti = fmi = oi = 0
    next
  }

  sec == "axes" && isrow($0) {
    n = split($0, c, "|")
    if (!hdr) {
      hdr = 1; have_axes = 1
      for (i = 2; i < n; i++) {
        h = tolower(trim(c[i]))
        if (h ~ /axis/)                 ai  = i
        if (h ~ /level/)                li  = i
        if (h ~ /enabl|active|^on$/)    ei  = i
      }
      next
    }
    axis = tolower(trim(ai  ? c[ai]  : ""))
    en   = tolower(trim(ei  ? c[ei]  : ""))
    lv   =         trim(li  ? c[li]  : "")
    if (axis !~ /^(tech-stack|tech|stack|architecture|arch|domain-implementation|domain)$/) {
      print "  X  axes: unknown axis [" axis "] — allowed: tech-stack, architecture, domain-implementation"
      af = 1
    }
    enabled  = ei ? (en ~ /^(yes|on|true|1|enabled|active)$/)   : (lv != "")
    disabled = ei ? (en ~ /^(no|off|false|0|disabled|inactive)$/) : 0
    if (li && enabled && !disabled && lv == "") {
      print "  X  axes: axis [" axis "] is enabled but has no level — set a level or mark it disabled"
      af = 1
    }
    next
  }

  sec == "gaps" && isrow($0) {
    n = split($0, c, "|")
    if (!hdr) {
      hdr = 1; have_gaps = 1
      for (i = 2; i < n; i++) {
        h = tolower(trim(c[i]))
        if (h ~ /status/)                    sti = i
        if (h ~ /form/)                      fmi = i
        if (h ~ /original|expected|answer/)  oi  = i
      }
      next
    }
    st = tolower(trim(sti ? c[sti] : ""))
    fm = tolower(trim(fmi ? c[fmi] : ""))
    og =         trim(oi  ? c[oi]  : "")
    if (st == "open") open++
    # Status is an enum, and misplaced is a member: a marker found in ANOTHER worktree is neither
    # solved nor expired (issue #13). A status outside the enum is a row flow B can never close.
    if (sti && st != "" && st !~ /^(open|solved|solved-with-hint|solved-with-solution|expired|misplaced|resolved \(claude\))$/) {
      print "  X  gaps: unknown status [" st "] — allowed: open, solved, solved-with-hint, solved-with-solution, expired, misplaced, resolved (Claude)"
      gf = 1
    }
    if (fmi && fm == "socratic") {
      if (og == "" || og == "-" || og == "--" || og == "n/a") {
        print "  X  gaps: a socratic gap has no recorded expected answer — it can never be marked solved"
        gf = 1
      }
    }
    next
  }

  END {
    if (have_axes) {
      if (!af) print "  OK axes: every label is a valid axis and every enabled axis has a level"
    } else {
      print "  ~  no [## Learning axes] table — axis checks skipped (legacy/divergent ledger)"
    }
    if (have_gaps) {
      if (open > 1) { print "  X  gaps: " open " open gaps — at most ONE may be open at a time"; gf = 1 }
      else          print "  OK gaps: at most one open gap"
      if (!fmi) print "  ~  gap log has no Form column — the socratic-answer check was skipped (legacy ledger)"
    } else {
      print "  ~  no [## Gap log] table — gap checks skipped (legacy/divergent ledger)"
    }
    exit (af || gf) ? 1 : 0
  }
' "$LEDGER"
FAIL=$?

echo
[ "$FAIL" -eq 0 ] && echo "VERDICT: OK" || echo "VERDICT: FAILED — the ledger is not internally consistent."
exit "$FAIL"
