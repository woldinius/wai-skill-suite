#!/usr/bin/env sh
# cross-issue-digest.sh — the notes a team run leaves on OTHER people's issues, gathered so none
# evaporates.
#
# A long run touches many issues in passing: it references #this from a comment on #that, it learns
# that #A actually depends on #B, it discovers a real problem on an issue it is not working. The
# landing rule says a genuine finding gets FILED — but the raw material for that decision is scattered
# across every issue the run brushed against, and asking a model to remember, at report time, every
# comment it made three hours ago on an issue outside the set is the please-remember pattern ADR-0002
# retired. So a script re-reads the backlog for edits SINCE THE RUN STARTED, on issues OUTSIDE the
# worked set, and hands back the candidates. The model curates; nothing is filed automatically.
#
# WHAT IT GATHERS (mechanical): #-references, depends-on / blocked-by relations, and the text of
# comments added since the run's start timestamp — grouped by issue and deduped within each group.
# WHAT IT DOES NOT DECIDE (judgment): which candidate is a real dependency vs a passing mention, how
# to phrase it, or whether it rises to a filed issue. It marks the references that point back INTO
# the worked set, because those are the ones most likely to matter — but a mark is a hint, not a
# verdict. ADR-0003: present any catalog ID as ID + dimension NAME; never copy a bare ID across the
# upstream/local boundary — that translation is the curator's, and this script never resolves an ID.
#
#   exit 0  digest produced — INCLUDING an empty one (no cross-issue activity since the start is a
#           valid, common answer, and it says so rather than staying silent)
#   exit 2  gh is missing/unauthenticated, the required arguments are absent, or the backlog listing
#           failed — UNKNOWN. The digest cannot be bounded to the run, so it is not produced; the
#           report notes the gap instead of pretending there was nothing to gather.
#
# Usage: sh cross-issue-digest.sh <run-start-ts> <worked-set>
#          run-start-ts : the run's START, e.g. 2026-08-02T12:00:00Z (compared to the minute)
#          worked-set   : the issues the run itself worked, so they are EXCLUDED here — space- or
#                         comma-separated, '#' optional, e.g. "12 13 14" or "#12,#13,#14"

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX word/glob semantics required

START="${1:-}"
WORKED="${2:-}"
if [ -z "$START" ] || [ -z "$WORKED" ]; then
  echo "cross-issue-digest: need <run-start-ts> and <worked-set> — cannot bound the digest (UNKNOWN)." >&2
  echo "  usage: sh cross-issue-digest.sh <run-start-ts> <worked-set>" >&2
  exit 2
fi

command -v gh >/dev/null 2>&1 || { echo "cross-issue-digest: gh is not installed — cannot read the backlog (UNKNOWN)." >&2; exit 2; }
gh auth status >/dev/null 2>&1 || { echo "cross-issue-digest: gh is not authenticated — cannot read the backlog (UNKNOWN)." >&2; exit 2; }

# The worked set as a space-padded token string, so `index(ws, " N ")` is an exact-number test that
# never matches a substring (12 must not match 123). '#' and ',' both become spaces.
WS=" $(printf '%s' "$WORKED" | tr ',#' '  ' | tr -s ' ') "
# Compare timestamps to the MINUTE only. The gate ledger stamps minutes and a run START stamps
# seconds; truncating both to 16 chars (YYYY-MM-DDTHH:MM) makes the comparison exact and format-safe.
START16="$(printf '%s' "$START" | cut -c1-16)"

CAP=80   # bound the per-issue gh calls; a backlog larger than this is noted as truncated, not silently cut

# Candidate issues: every issue (any state) with an update at/after START, minus the worked set.
LIST="$(gh issue list --state all --limit 300 --json number,title,updatedAt \
        --jq '.[] | [(.number|tostring), .updatedAt, ((.title // "") | gsub("\n";" ") | gsub("\t";" "))] | join("\t")' 2>/dev/null)"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "cross-issue-digest: gh could not list issues (exit $rc) — UNKNOWN, note the gap in the report." >&2
  exit 2
fi

echo "cross-issue-digest: activity since $START on issues OUTSIDE the worked set ($WORKED)"
echo

# Filter to candidates in the shell/awk, then walk each one. `updatedAt` is ISO-8601 UTC, so a
# 16-char string compare orders it correctly.
CANDS="$(printf '%s\n' "$LIST" | awk -F'\t' -v start="$START16" -v ws="$WS" '
  { num=$1; upd=$2
    if (upd == "") next
    if (substr(upd,1,16) < start) next          # not touched during the run
    if (index(ws, " " num " ")) next            # part of the worked set — excluded by design
    print $0
  }')"

if [ -z "$CANDS" ]; then
  echo "  (no issues outside the worked set were touched since the run started)"
  echo
  echo "NOTE: an empty digest is a valid answer — no cross-issue notes to consolidate."
  exit 0
fi

TOTAL="$(printf '%s\n' "$CANDS" | grep -c . 2>/dev/null || true)"
PRINTED=0
FAILED=0
SEEN=0

printf '%s\n' "$CANDS" | { while IFS="$(printf '\t')" read -r NUM UPD TITLE; do
  [ -n "$NUM" ] || continue
  SEEN=$((SEEN + 1))
  if [ "$SEEN" -gt "$CAP" ]; then
    echo "  … more than $CAP candidate issues; the rest were not fetched. Re-run with a tighter"
    echo "    worked set or a later start if you need them."
    break
  fi

  # Pull the body + every comment (with its createdAt) as tab-tagged lines. A per-issue fetch can
  # fail transiently without gh being 'unavailable' — that is a gap on ONE issue, noted, not a run
  # failure, so it does not flip the exit code.
  # shellcheck disable=SC2016  # $n is a jq variable, not a shell one — single quotes are correct
  RAW="$(gh issue view "$NUM" --json number,title,body,comments \
         --jq '(.number|tostring) as $n
               | ("BODY\t\($n)\t\((.body // "") | gsub("\n";" ") | gsub("\t";" "))"),
                 (.comments[]? | "CMT\t\($n)\t\(.createdAt)\t\((.body // "") | gsub("\n";" ") | gsub("\t";" "))")' \
         2>/dev/null)" || { FAILED=$((FAILED + 1)); echo "  #$NUM — could not read (skipped this issue)"; continue; }

  BLOCK="$(printf '%s\n' "$RAW" | awk -F'\t' -v n="$NUM" -v title="$TITLE" -v upd="$UPD" -v start="$START16" -v ws="$WS" '
    function addref(r) { if (!(r in seenref)) { seenref[r]=1; refs[++nref]=r } }
    function addrel(r) { if (!(r in seenrel)) { seenrel[r]=1; rels[++nrel]=r } }
    function refs_of(s) { while (match(s, /#[0-9]+/)) { addref(substr(s, RSTART, RLENGTH)); s = substr(s, RSTART + RLENGTH) } }
    function rels_of(s,   bs, bl, tok) {
      while (match(s, /(depends on|depends-on|blocked by|blocked-by|blocked on|needs) *#[0-9]+/)) {
        bs = RSTART; bl = RLENGTH; tok = substr(s, bs, bl); addrel(tok); s = substr(s, bs + bl)
      }
    }
    $1 == "BODY" { refs_of($3); rels_of(tolower($3)) }
    $1 == "CMT"  {
      if (substr($3, 1, 16) >= start) {
        refs_of($4); rels_of(tolower($4))
        snips[++nsnip] = $3 " | " substr($4, 1, 140)
      }
    }
    END {
      if (nref == 0 && nrel == 0 && nsnip == 0) exit 0   # touched but no textual signal — skip it
      printf "  #%s  \"%s\"  (updated %s)\n", n, title, upd
      line = "    references: "
      if (nref == 0) line = line "none"
      else for (i = 1; i <= nref; i++) {
        num = refs[i]; gsub(/[^0-9]/, "", num)
        mark = (index(ws, " " num " ")) ? "*" : ""     # * = points back into the worked set
        line = line refs[i] mark " "
      }
      print line
      line = "    relations: "
      if (nrel == 0) line = line "none"
      else for (i = 1; i <= nrel; i++) line = line rels[i] "; "
      print line
      if (nsnip > 0) {
        print "    comments since start:"
        for (i = 1; i <= nsnip; i++) print "      - " snips[i]
      }
      print "PRINTED_ONE"
    }
  ')"

  if printf '%s\n' "$BLOCK" | grep -q '^PRINTED_ONE$'; then
    printf '%s\n' "$BLOCK" | grep -v '^PRINTED_ONE$'
    PRINTED=$((PRINTED + 1))
  fi
done

echo
if [ "$PRINTED" -eq 0 ]; then
  echo "  (issues were touched since start, but none carried a #-reference, a relation, or a"
  echo "   comment with textual content — nothing to consolidate)"
fi
echo "NOTE — this is RAW material for the Cross-issue notes section, not the section itself:"
echo "  · '*' marks a reference pointing back into the worked set — the likeliest to matter, not a verdict."
echo "  · you curate the survivors; a genuine finding is still FILED as its own issue (issues-protocol)."
echo "  · $TOTAL candidate issue(s) matched the window; $FAILED could not be read this run."
echo "  · ADR-0003: cite any catalog ID as ID + dimension name; never copy a bare ID across a repo boundary."
}
exit 0
