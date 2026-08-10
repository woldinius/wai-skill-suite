#!/usr/bin/env sh
# attack-path-lint.sh — is the "### Attack paths" section WELL-FORMED and correctly LINKED?
#
# THIS SCRIPT VALIDATES FORM, NOT TRUTH — and it says so on every run. It cannot tell you whether a
# kill-chain is real, whether the pivot is actually reachable, or whether the severity is right. A
# fictional but tidy chain passes clean. What it CAN check is the machinery the synthesis stage
# depends on: that every finding handle a chain cites actually resolves to a finding (a dangling
# handle is the ADR-0003 renumber hazard made concrete — a finding gets renumbered and a chain now
# points at nothing, or worse, at someone else's finding); that each chain carries the four fields a
# reader needs to act (a severity, at least one linked finding, an objective, and the cheapest link to
# break); and that no Blocker/Major finding was quietly left out of the synthesis — every one must sit
# in a chain OR on the Standalone line.
#
# WHAT IT DELIBERATELY DOES NOT CHECK: chain-severity monotonicity. A chain can legitimately rank
# BELOW its worst link — a present-but-neutralised step lowers real reachability — and no script can
# tell that from an authoring error. Rendering a verdict it cannot justify is how a lint gets switched
# off (ADR-0002). So it checks that a severity FIELD exists and parses, never that the number is right.
#
#   exit 0  well-formed — OR there is no Attack paths section AND no Blocker/Major finding to account
#           for (a report with nothing to chain is not a broken report; it should say so in Posture)
#   exit 1  a form/linkage check failed — the reasons name the repair
#   exit 2  the report could not be read
#
# Usage: sh attack-path-lint.sh [report.md] [quality-attributes.md]
#        (report default: read from the path given; catalog is OPTIONAL — cited IDs are only
#         cross-checked when a readable catalog is supplied, else that check SKIPS)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

REPORT="${1:-}"
CAT="${2:-}"

[ -n "$REPORT" ] || { echo "attack-path-lint: no report given." >&2; echo "usage: sh attack-path-lint.sh [report.md] [quality-attributes.md]" >&2; exit 2; }
{ [ -f "$REPORT" ] && [ -r "$REPORT" ]; } || { echo "attack-path-lint: cannot read report '$REPORT' — UNKNOWN." >&2; exit 2; }

FAIL=0
note() { echo "  ✗ $1"; FAIL=1; }
pass() { echo "  ✓ $1"; }
skip() { echo "  ⚠ $1"; }
hint() { echo "      $1"; }

echo "attack-path-lint: $REPORT"
echo "  · VALIDATES FORM (well-formedness + finding-handle linkage), NOT TRUTH (a fictional but tidy"
echo "    chain passes; reachability and correct severity are the auditor's judgment, not this script's)."

# One awk pass extracts the structured facts; the shell renders the verdict. Handles are F<n> with a
# non-alphanumeric boundary on BOTH sides so `F1` in `conFig` or `F1x` is never mistaken for a handle;
# catalog IDs are backticked `FAMILY-<n>`, a distinct namespace from the ephemeral F-handles.
REC="$(awk '
  function extract_handles(s,   rest, tok, ap, before, after, ok) {
    nH = 0; rest = s
    while (match(rest, /F[0-9]+/)) {
      tok = substr(rest, RSTART, RLENGTH); ok = 1
      if (RSTART > 1) { before = substr(rest, RSTART-1, 1); if (before ~ /[A-Za-z0-9]/) ok = 0 }
      ap = RSTART + RLENGTH
      if (ap <= length(rest)) { after = substr(rest, ap, 1); if (after ~ /[A-Za-z0-9]/) ok = 0 }
      if (ok) { nH++; H[nH] = tok }
      rest = substr(rest, ap)
    }
  }
  function extract_catids(s,   rest, tok) {
    nC = 0; rest = s
    while (match(rest, /`[A-Z][A-Z]*-[0-9]+`/)) {
      tok = substr(rest, RSTART+1, RLENGTH-2); nC++; C[nC] = tok
      rest = substr(rest, RSTART + RLENGTH)
    }
  }
  function ap_reset() { has_sev=0; has_fref=0; has_obj=0; has_cheap=0; ap_label="" }
  function flush_ap(   miss) {
    apn++; miss=""
    if (!has_sev)   miss = miss " severity"
    if (!has_fref)  miss = miss " finding-handle-link"
    if (!has_obj)   miss = miss " objective-line"
    if (!has_cheap) miss = miss " cheapest-break-marker"
    if (miss != "") aperr[apn] = ap_label ":" miss
  }
  /^(# |## |### )/ {
    if (mode == "attack" && ap_open) { flush_ap(); ap_open=0 }
    if ($0 ~ /^### +[Ff]indings/)            { mode="findings"; fsec=1; cursev=""; next }
    else if ($0 ~ /^### +[Aa]ttack [Pp]aths/) { mode="attack";   asec=1; ap_open=0; next }
    else                                      { mode=""; next }
  }
  {
    if (mode == "findings") {
      if ($0 ~ /^#### /) { cursev = tolower($0); sub(/^#### +/, "", cursev); sub(/[^a-z].*/, "", cursev); next }
      extract_handles($0)
      for (i=1; i<=nH; i++) { DEF[H[i]] = cursev; DEFC[H[i]]++ }
    } else if (mode == "attack") {
      if ($0 ~ /[Ss]tandalone/) { if (ap_open) { flush_ap(); ap_open=0 } }
      else if ($0 ~ /^[^A-Za-z0-9]*AP-?[0-9]+/) {
        if (ap_open) flush_ap()
        ap_open=1; ap_reset()
        match($0, /AP-?[0-9]+/); ap_label = substr($0, RSTART, RLENGTH)
      }
      extract_handles($0); for (i=1; i<=nH; i++) REF[H[i]]=1
      hcount = nH
      extract_catids($0); for (i=1; i<=nC; i++) CATID[C[i]]=1
      if (ap_open) {
        if ($0 ~ /[Bb]locker|[Mm]ajor|[Mm]inor|[Cc]ritical|[Hh]igh|[Mm]edium|[Ll]ow|[Nn]it|[Ii]nfo/) has_sev=1
        if (hcount >= 1) has_fref=1
        if ($0 ~ /[Oo]bjective/) has_obj=1
        if ($0 ~ /✂|[Cc]heapest/) has_cheap=1
      }
    }
  }
  END {
    if (mode == "attack" && ap_open) flush_ap()
    print "SEC_FINDINGS " (fsec+0)
    print "SEC_ATTACK "   (asec+0)
    print "AP_COUNT "     (apn+0)
    for (h in DEF)   print "DEF "   h " " (DEF[h]=="" ? "-" : DEF[h]) " " DEFC[h]
    for (h in REF)   print "REF "   h
    for (c in CATID) print "CATID " c
    for (k=1; k<=apn; k++) if (k in aperr) print "APERR" aperr[k]
  }
' "$REPORT")"

get1() { printf '%s\n' "$REC" | sed -n "s/^$1 //p" | head -1; }
ASEC="$(get1 SEC_ATTACK)"
FSEC="$(get1 SEC_FINDINGS)"

DEFS="$(printf '%s\n' "$REC" | awk '$1=="DEF"{print $2}' | sort -u)"
REFS="$(printf '%s\n' "$REC" | awk '$1=="REF"{print $2}' | sort -u)"
BM="$(printf '%s\n' "$REC" | awk '$1=="DEF" && ($3=="blocker"||$3=="major"){print $2}' | sort -u)"

# --- No Attack paths section: valid only if there is nothing that MUST be accounted for -----------
if [ "${ASEC:-0}" != "1" ]; then
  if [ -n "$BM" ]; then
    note "Blocker/Major finding(s) exist [$(printf '%s' "$BM" | tr '\n' ' ')] but there is no '### Attack paths' section to chain them or list them standalone"
    hint "add the Attack paths section: synthesise chains, and list any unchained Blocker/Major on a Standalone line."
    echo
    echo "VERDICT: FAILED"
    exit 1
  fi
  if [ "${FSEC:-0}" != "1" ]; then
    pass "no Findings and no Attack paths section — nothing to validate"
  else
    pass "no Attack paths section and no Blocker/Major findings — nothing to chain (say so in Posture)"
  fi
  echo
  echo "VERDICT: OK"
  exit 0
fi

# --- 1. Every cited F-handle resolves to a defined finding (the renumber guard) -------------------
DANGLING=""
for r in $REFS; do
  printf '%s\n' "$DEFS" | grep -qx "$r" || DANGLING="$DANGLING $r"
done
if [ -n "$DANGLING" ]; then
  note "an attack path cites finding handle(s) that resolve to NO finding:$DANGLING"
  hint "a dangling handle is the ADR-0003 renumber hazard — the finding moved or was dropped. Re-point or restore it."
else
  N_REF="$(printf '%s\n' "$REFS" | grep -c . || true)"
  pass "every cited F-handle ($N_REF) resolves to a defined finding"
fi

# --- 2. Handle uniqueness (hard) + contiguity (advisory) -----------------------------------------
DUP="$(printf '%s\n' "$REC" | awk '$1=="DEF" && $4>1 {print $2}' | sort -u | tr '\n' ' ')"
if [ -n "$DUP" ]; then
  note "finding handle defined more than once: $DUP — a handle must name exactly one finding"
else
  pass "no finding handle is defined twice"
fi
NUMS="$(printf '%s\n' "$DEFS" | sed -n 's/^F//p' | grep -E '^[0-9]+$' | sort -n)"
if [ -n "$NUMS" ]; then
  MAX="$(printf '%s\n' "$NUMS" | tail -1)"
  GAPS=""; i=1
  while [ "$i" -le "$MAX" ]; do
    printf '%s\n' "$NUMS" | grep -qx "$i" || GAPS="$GAPS F$i"
    i=$((i + 1))
  done
  [ -n "$GAPS" ] && skip "finding handles are not contiguous (missing:$GAPS) — usually a renumber/drop left a hole (advisory)"
fi

# --- 3. Each AP block carries its four required fields --------------------------------------------
APERRS="$(printf '%s\n' "$REC" | sed -n 's/^APERR//p')"
if [ -n "$APERRS" ]; then
  printf '%s\n' "$APERRS" | while IFS= read -r e; do
    [ -n "$e" ] || continue
    _lbl="${e%%:*}"; _miss="${e#*:}"
    echo "  ✗ attack path $_lbl is missing:$_miss"
  done
  FAIL=1
else
  APC="$(get1 AP_COUNT)"
  if [ "${APC:-0}" = "0" ]; then
    skip "the Attack paths section has no AP-<n> chain block (only standalone/prose) — that is valid if no chain reached an objective"
  else
    pass "every AP chain block carries a severity, a linked finding, an objective and a cheapest-break marker"
  fi
fi

# --- 4. Every Blocker/Major finding is chained OR listed standalone -------------------------------
if [ -n "$BM" ]; then
  UNACC=""
  for b in $BM; do
    printf '%s\n' "$REFS" | grep -qx "$b" || UNACC="$UNACC $b"
  done
  if [ -n "$UNACC" ]; then
    note "Blocker/Major finding(s) neither chained nor listed standalone:$UNACC"
    hint "every Blocker/Major must appear in at least one chain OR on the Standalone line — none may silently drop out of the synthesis."
  else
    pass "every Blocker/Major finding is accounted for (chained or standalone)"
  fi
else
  pass "no Blocker/Major findings to account for"
fi

# --- 5. Cited catalog IDs resolve — advisory, and only when a catalog is supplied -----------------
CATIDS="$(printf '%s\n' "$REC" | awk '$1=="CATID"{print $2}' | sort -u)"
if [ -n "$CATIDS" ]; then
  if [ -n "$CAT" ] && [ -r "$CAT" ]; then
    DANG=""
    for c in $CATIDS; do
      grep -qE "^- \*\*$c([^0-9]|$)" "$CAT" || DANG="$DANG $c"
    done
    if [ -n "$DANG" ]; then
      skip "cited catalog ID(s) not found in $CAT:$DANG (advisory — check the citation; not a form failure)"
    else
      pass "every cited catalog ID resolves in the catalog"
    fi
  else
    skip "catalog IDs are cited but no readable catalog was given — ID resolution SKIPPED (pass one as arg 2)"
  fi
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "VERDICT: OK — the Attack paths section is well-formed (form only; truth is the auditor's)."
  exit 0
else
  echo "VERDICT: FAILED — the Attack paths section is malformed or mis-linked (this is about form, not truth)."
  exit 1
fi
