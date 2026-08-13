#!/usr/bin/env sh
# run-log.sh — one appended row per skill run: the suite's attendance record.
#
# Issue #11, measured in the field: a skill leaves a trace today ONLY if it files something — a gate
# verdict, an issue. A security audit that finds nothing, a team run over eight issues and three
# hours, a planning pass that comments on an existing issue: all ran, all vanished. THE RECORD
# MEASURES SIDE EFFECTS, NOT WORK — and it is confident enough to be misread: counting issues by
# skill showed 3 planning findings against 58 from pr-review, and a report concluded from that that
# almost every PR was planned. The number was right; it measured issue creation, not value produced.
# This file is the missing denominator. One row per run, written at hand-back, append-only like the
# gate ledger: a run without a row is invisible work.
#
# Deliberately NOT a second ledger to tag: the gate ledger's value comes from the human judging each
# row, and asking for that twice would kill both. This is pure attendance — who ran, on what, with
# what result in a half-sentence.
#
# WHO CALLS THIS — two tiers, and ATTRIBUTION decides the tier:
#   · Tier 1 — scripts that self-log. A script may append the row itself ONLY when its script↔skill
#     mapping is 1:1 AND running it marks a real skill run. Three qualify today:
#       merge-gate.sh    → wai-pr-review       (a gate verdict IS a review run)
#       backlog-scan.sh  → wai-team            (the scan opens every team run)
#       dep-cve-scan.sh  → wai-security-audit  (the CVE sweep marks the audit)
#     Shared or ambiguous scripts MUST NOT self-log: catalog-lint.sh runs from wai-init, from
#     pr-review AND from the test bed, so a row from it would attribute one run to three skills — or
#     a test to a skill. doctor.sh and the lints are maintenance, not skill runs. A WRONG row is
#     worse than a missing one: it is a datum someone will count.
#   · Tier 2 — prompts. The prose-only skills (planning, implementation, testing, the audits' prose
#     halves, cicd, mobile-release) log at their hand-off step, per their SKILL.md.
#
# FAIL-OPEN, like the gate's emit_ledger and for the same reason: a LOGGING failure must never break
# or change a RUN. Every write is best-effort (`|| true`); an unwritable target still exits 0.
# Losing a row is a data gap; failing a finished run over a read-only file would be a real cost.
#
#   exit 0  the row was emitted — or emission failed and was swallowed (fail-open, stderr says so)
#   exit 2  misuse: fewer than three non-empty arguments. The only defined negative; there is
#           deliberately no exit 1, because this script renders no verdict about anything.
#
# Usage: sh run-log.sh <skill> <subject> <outcome>
#        Appends to docs/architecture/run-log.md (cwd-relative; $RUN_LOG overrides the path — the
#        same pattern as $MERGE_GATE_LEDGER on the gate ledger).

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

if [ $# -lt 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "run-log: usage: sh run-log.sh <skill> <subject> <outcome> — all three required." >&2
  exit 2
fi

LOG="${RUN_LOG:-docs/architecture/run-log.md}"

# One table-safe cell: newlines flattened, pipes escaped, whitespace collapsed — emit_ledger's sed
# shape — then capped at 120 chars ON A WORD BOUNDARY with a visible '…', for emit_ledger's reason:
# a silent cut reads exactly like a complete sentence.
cell() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/|/\//g; s/[[:space:]]\{1,\}/ /g; s/^ *//; s/ *$//' \
    | awk '{ if (length($0) <= 120) print; else { s = substr($0, 1, 120); sub(/ [^ ]*$/, "", s); print s "…" } }'
}

if [ ! -f "$LOG" ]; then
  mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
  # A quoted heredoc: every line literal. The header carries its own protocol, so it costs zero
  # skill words and cannot be lost — the same trick as the gate ledger's.
  cat > "$LOG" 2>/dev/null <<'RUNLOG_HDR' || true
# Run log

One row per skill run — pure attendance: who ran, on what, with what result in a half-sentence.
Written by the skill (or its script) at hand-back, never reconstructed afterwards from memory.
**A run without a row is invisible work:** without this file a skill leaves a trace only if it
files something, so an audit that finds nothing, a batch run that bundles its output, or a planning
pass that comments on an existing issue simply vanishes — the record measures side effects, not
work. This file is the denominator for every "how often does X actually run" question.

**APPEND-ONLY.** Never edit or delete a past row; the count only means something if nobody curates
it. Unlike the gate ledger there is no outcome column to tag — nothing here asks for judgment, and
a suite update must never touch this file (the same never-eaten guarantee as the gate ledger's).

| when (UTC) | skill | subject | outcome |
|---|---|---|---|
RUNLOG_HDR
fi

if printf '| %s | %s | %s | %s |\n' \
     "$(date -u +%Y-%m-%dT%H:%MZ 2>/dev/null || echo '?')" \
     "$(cell "$1")" "$(cell "$2")" "$(cell "$3")" >> "$LOG" 2>/dev/null; then
  echo "run-log: $1 · row appended to $LOG"
else
  echo "run-log: could not write $LOG — the row is lost, the run is not (fail-open)." >&2
fi
exit 0
