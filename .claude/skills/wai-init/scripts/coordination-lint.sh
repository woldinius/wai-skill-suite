#!/usr/bin/env sh
# coordination-lint.sh — is this repo's autonomy + comms config safe to act on?
#
# `coordination.conf` decides what an agent may do WITHOUT a human: arm an autonomous drain, post to a
# channel. A config that is wrong in the SAFE direction (autonomy off) costs nothing. A config that is
# wrong in the UNSAFE direction — a narrowed exclusion floor, an allowlist that authorises too much, a
# webhook SECRET committed in the clear — costs everything, silently, and looks identical to a working
# one. So the config gets the same treatment as the merge gate: a script owns the mechanical checks,
# because "the model read the config and it looked fine" is not something anyone can audit.
#
# THE ONE INVARIANT THIS FILE PROTECTS: the six policy domains that stay the human's in EVERY mode may
# only ever be WIDENED, never narrowed. And the floor is NOT typed here — a second copy of a security
# list is a second copy to drift. It is SOURCED, live, from the one authority:
#     excluded-domains.sh --list-domains --policy-only
# If that authority cannot be reached, this lint returns UNKNOWN. It never falls back to a guess.
#
#   exit 0  consistent — or the file is ABSENT (autonomy off, comms none: the safe default is a pass)
#   exit 1  a check failed — printed WITHOUT ever echoing a secret value; the repair is named
#   exit 2  UNKNOWN — the conf/catalog is unreadable, or the policy-domain floor could not be sourced.
#           Fail-closed: a config that cannot be verified must not be trusted to arm autonomy.
#
# Usage: sh coordination-lint.sh [coordination.conf] [quality-attributes.md]
#        (defaults: docs/architecture/coordination.conf · docs/architecture/quality-attributes.md)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX word-split + pattern semantics

CONF="${1:-docs/architecture/coordination.conf}"
CAT="${2:-docs/architecture/quality-attributes.md}"
# Risk PATHS are inherited from merge-gate.conf, the sibling of the conf we were handed — one source
# of truth for "which paths are dangerous", never duplicated into coordination.conf.
MGCONF="$(dirname "$CONF")/merge-gate.conf"

# Where the single authority lives, resolved from THIS script's own location (so cwd does not matter),
# with a cwd-relative fallback for a repo run from its root.
SELF="$(dirname "$0")"
ED=""
for _c in "$SELF/../../wai/scripts/excluded-domains.sh" ".claude/skills/wai/scripts/excluded-domains.sh"; do
  [ -f "$_c" ] && { ED="$_c"; break; }
done

# A repo-local file is PARSED, never sourced — executing it would be an injection vector, and this
# runs where credentials and a webhook secret live. Every key is greped, one line, quotes stripped.
val() { sed -n "s/^$1=//p" "$2" 2>/dev/null | tr -d '"' | head -1; }

FAIL=0
note() { echo "  ✗ $1"; FAIL=1; }
pass() { echo "  ✓ $1"; }
hint() { echo "      $1"; }

echo "coordination-lint: $CONF"

# --- Absent is the safe default, and a pass -----------------------------------------------------
# An absent file means exactly what the template's defaults mean: autonomy off, comms none. There is
# nothing to get wrong, so there is nothing to fail. (A file that EXISTS but cannot be READ is a
# different thing — that is an UNKNOWN, below.)
if [ ! -e "$CONF" ]; then
  echo "  · no $CONF — autonomy is off and comms is none (the fail-closed default). Nothing to validate."
  echo "VERDICT: OK"
  exit 0
fi
[ -r "$CONF" ] || { echo "coordination-lint: $CONF exists but cannot be read — UNKNOWN." >&2; exit 2; }

# --- Comms hygiene — checked in EVERY mode ------------------------------------------------------
# A repo may configure comms with autonomy off, so these run regardless of AUTONOMY_ENABLED.

TOOL="$(val COMMS_TOOL "$CONF")"
case "${TOOL:-none}" in
  none|github-coordination|slack|discord|matrix)
    pass "COMMS_TOOL='${TOOL:-none}' is in the allowed set" ;;
  *)
    note "COMMS_TOOL='$TOOL' is not in the allowed set (none|github-coordination|slack|discord|matrix)" ;;
esac

# COMMS_WEBHOOK_ENV is the NAME of an env var, never the secret itself (SEC-3). A NAME matches
# ^[A-Z_][A-Z0-9_]*$; anything with a scheme or a slash is a literal URL/token that must not be here.
WENV="$(val COMMS_WEBHOOK_ENV "$CONF")"
if [ -z "$WENV" ]; then
  pass "COMMS_WEBHOOK_ENV is empty (no webhook, or it is supplied by the environment) "
elif printf '%s' "$WENV" | grep -qE '^[A-Z_][A-Z0-9_]*$'; then
  pass "COMMS_WEBHOOK_ENV names an environment variable, not a literal secret (SEC-3)"
else
  note "COMMS_WEBHOOK_ENV must be an ENV-VAR NAME (e.g. TEAM_COORD_WEBHOOK_URL), not a URL or token (SEC-3)"
  hint "store the secret in the environment; commit only the variable's name."
fi

# A committed secret is a leaked secret, forever. Scan the whole file for KNOWN token shapes and
# webhook-URL shapes. Report the LINE, never the value — printing the match would re-leak it.
SECRET_LINES="$(grep -nE '(-----BEGIN [A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{8,}|sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{12,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|https?://[A-Za-z0-9.-]*hooks[A-Za-z0-9./_-]*|https?://[A-Za-z0-9.-]+/services/[A-Za-z0-9]+)' "$CONF" 2>/dev/null | cut -d: -f1 | tr '\n' ' ' || true)"
if [ -n "$SECRET_LINES" ]; then
  note "a value matching a known secret/webhook-URL shape is committed at line(s): $SECRET_LINES (value hidden)"
  hint "remove it, rotate the secret, and store only the ENV-VAR NAME (SEC-3)."
else
  pass "no committed secret/webhook-URL shape found"
fi

# --- Autonomy — only when it is actually enabled ------------------------------------------------
AUT="$(val AUTONOMY_ENABLED "$CONF")"
if [ "${AUT:-no}" != "yes" ]; then
  pass "autonomy disabled (AUTONOMY_ENABLED='${AUT:-no}') — the safe default; no autonomy checks apply"
  echo
  if [ "$FAIL" -eq 0 ]; then echo "VERDICT: OK"; exit 0; else echo "VERDICT: FAILED"; exit 1; fi
fi

# From here down, autonomy is ARMED — the checks below are load-bearing.

# 1. The six-policy-domain FLOOR, sourced live from the one authority. No typed copy lives here.
if [ -z "$ED" ]; then
  echo "coordination-lint: cannot locate excluded-domains.sh — the policy-domain floor is unverifiable (UNKNOWN)." >&2
  exit 2
fi
FLOOR_TAGS="$(sh "$ED" --list-domains --policy-only 2>/dev/null | awk 'NF{print $1}' | grep -E '^EX-' | sort -u || true)"
if [ -z "$FLOOR_TAGS" ]; then
  echo "coordination-lint: 'excluded-domains.sh --list-domains --policy-only' produced no floor — unverifiable (UNKNOWN)." >&2
  exit 2
fi

EXCL="$(val AUTONOMY_EXCLUDED "$CONF")"
# Each entry is TAG:name:id — take the tag (field 1). These are the domains the conf claims to exclude.
CONF_TAGS="$(printf '%s\n' "$EXCL" | tr -s ' \t' '\n' | grep -E '.' | cut -d: -f1 | grep -E '^EX-' | sort -u || true)"

MISSING=""
for _t in $FLOOR_TAGS; do
  printf '%s\n' "$CONF_TAGS" | grep -qx "$_t" || MISSING="$MISSING $_t"
done
if [ -n "$MISSING" ]; then
  note "AUTONOMY_EXCLUDED is NARROWER than the policy floor — missing:$MISSING"
  hint "the floor may only be WIDENED, never narrowed. Restore the missing tag(s)."
  hint "the authoritative set is 'excluded-domains.sh --list-domains --policy-only'."
else
  N_FLOOR="$(printf '%s\n' "$FLOOR_TAGS" | grep -c . || true)"
  pass "all $N_FLOOR policy domains present in AUTONOMY_EXCLUDED (floor intact; widening is allowed)"
fi

# 2. Any FILLED catalog-ID anchor (field 3) must resolve to a live dimension in THIS repo's catalog.
#    The template ships these EMPTY on purpose (ADR-0003 — a bare copied ID rebinds); a dangling one
#    means an anchor init resolved once has since moved, and the reference now points at nothing.
ANCHORS="$(printf '%s\n' "$EXCL" | tr -s ' \t' '\n' | grep -E '.' | awk -F: 'NF>=3 && $3!="" {print $3}' | sort -u || true)"
if [ -n "$ANCHORS" ]; then
  if [ ! -r "$CAT" ]; then
    echo "coordination-lint: AUTONOMY_EXCLUDED carries ID anchors but catalog '$CAT' is unreadable — cannot verify them (UNKNOWN)." >&2
    exit 2
  fi
  DANGLING=""
  for _a in $ANCHORS; do
    grep -qE "^- \*\*$_a([^0-9]|$)" "$CAT" || DANGLING="$DANGLING $_a"
  done
  if [ -n "$DANGLING" ]; then
    note "AUTONOMY_EXCLUDED anchors an ID that does not resolve in $CAT:$DANGLING"
    hint "re-resolve the domain by NAME against this repo's catalog, or clear the ID slot (the name alone is enough)."
  else
    pass "every filled ID anchor resolves to a live catalog dimension"
  fi
else
  pass "no bare ID anchors filled — domains are named, not numbered (ADR-0003)"
fi

# 3. The four preconditions autonomy cannot arm without. CONTRACT_PATHS and ERASURE_PATHS are
#    INHERITED from merge-gate.conf (not duplicated); SAFE_PATHS and AFFIRMED live here.
SAFE="$(val AUTONOMY_SAFE_PATHS "$CONF")"
AFF="$(val AUTONOMY_AFFIRMED "$CONF")"
if [ -r "$MGCONF" ]; then
  CP="$(val CONTRACT_PATHS "$MGCONF")"
  EP="$(val ERASURE_PATHS "$MGCONF")"
else
  CP=""; EP=""
  note "autonomy is enabled but $MGCONF is missing — CONTRACT_PATHS/ERASURE_PATHS are undefined, so the blocklist floor cannot be inherited"
  hint "run wai-init to write merge-gate.conf (with non-empty CONTRACT_PATHS and ERASURE_PATHS) before arming autonomy."
fi

[ -n "$SAFE" ] || { note "AUTONOMY_SAFE_PATHS is empty — the allowlist authorises NO path, so autonomy would drain nothing (and must not arm)"; hint "name the paths a human affirmed as safe; anything outside them is held for the human."; }
[ -n "$AFF" ]  || { note "AUTONOMY_AFFIRMED is empty — no human affirmed this surface; autonomy stays off"; hint "record a date + a fingerprint of the safe set a human signed off on."; }
[ -r "$MGCONF" ] && { [ -n "$CP" ] || note "CONTRACT_PATHS is empty in merge-gate.conf — under autonomy that means 'every path is contract-domain', which forbids draining anything; define it"; }
[ -r "$MGCONF" ] && { [ -n "$EP" ] || note "ERASURE_PATHS is empty in merge-gate.conf — the GDPR-erasure surface is unnamed; define it before arming autonomy"; }

if [ -n "$SAFE" ] && [ -n "$AFF" ] && [ -n "$CP" ] && [ -n "$EP" ]; then
  pass "autonomy preconditions met: safe-paths + contract-paths + erasure-paths non-empty and AUTONOMY_AFFIRMED present"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "VERDICT: OK"
  exit 0
else
  echo "VERDICT: FAILED — do not arm autonomy until the failures above are fixed."
  exit 1
fi
