#!/usr/bin/env sh
# rank-pr-candidates.sh — shortlist a clean wai-team run's PRs for ONE post-run learning gap.
#
# After a clean autopilot run, learning mode may offer the human a single gap drawn from the most
# instructive PR of that run (flow D). This emits the mechanical half of that choice: it filters the
# run's PRs through the SAME excluded-domain classifier the merge gate uses, then ranks the
# survivors by cheap proxies (a smaller, tighter diff makes a better single-concept gap). The model
# picks the instructive one from the shortlist; the script never claims to know which teaches best.
#
# THE EXCLUSION HALF CALLS excluded-domains.sh — it does NOT re-implement the risky list. A learning
# gap must never be planted on a payment, auth, contract, security, migration or erasure change:
# that is the same "excluded domains" set the whole suite gates on, defined once in
# agent-git-protocol.md. Re-typing it here would be a second copy to drift; instead this shells out
# to the one classifier. A PR the classifier cannot verify (UNKNOWN) is dropped, never offered —
# fail closed.
#
#   exit 0  a shortlist was printed (ranked, safe PRs)
#   exit 1  no eligible PR — every PR in the run was excluded (or none survived the filter)
#   exit 2  the run's PRs could not be read (empty/unreadable list, or none could be classified)
#
# What this does NOT decide: which PR is "most instructive", or which line/axis the gap lands on —
# both are model judgment. It emits a safe, ranked shortlist and stops.
#
# Usage:  sh rank-pr-candidates.sh <run-PR-list>
#   <run-PR-list> is a file with one PR number per line ('-' reads stdin). Blank lines and '#'
#   comments are ignored.
# Env:  EXCLUDED_DOMAINS_SH  override the classifier path (defaults to the wai sibling script).

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

SRC="${1:-}"
[ -n "$SRC" ] || { echo "rank-pr-candidates: usage: sh rank-pr-candidates.sh <run-PR-list>" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXCLUDED_DOMAINS_SH="${EXCLUDED_DOMAINS_SH:-$SCRIPT_DIR/../../wai/scripts/excluded-domains.sh}"

# --- Read the run's PR numbers ------------------------------------------------------------------
if [ "$SRC" = "-" ]; then
  PRS="$(cat 2>/dev/null || true)"
elif [ -r "$SRC" ]; then
  PRS="$(cat "$SRC" 2>/dev/null || true)"
else
  echo "rank-pr-candidates: cannot read the run's PR list at '$SRC' (UNKNOWN)." >&2
  exit 2
fi

# Keep only lines that are a bare PR number.
PRS="$(printf '%s\n' "$PRS" | sed 's/#.*//' | tr -d ' \t' | grep -E '^[0-9]+$' || true)"
if [ -z "$PRS" ]; then
  echo "rank-pr-candidates: no PR numbers in the run list (UNKNOWN — nothing to read)." >&2
  exit 2
fi

# classify PR → 0 clear · 1 excluded · 2 unknown (missing classifier, gh down, unreadable diff).
classify() {
  [ -x "$EXCLUDED_DOMAINS_SH" ] || return 2
  "$EXCLUDED_DOMAINS_SH" --pr "$1" >/dev/null 2>&1
  _rc=$?
  case "$_rc" in 0|1) return "$_rc" ;; *) return 2 ;; esac
}

# size proxy: number of files the PR touches (fewer ⇒ a tighter, better single-concept gap).
# Reads through gh; a survivor of `classify` already implies gh worked, so this rarely fails.
file_count() {
  command -v gh >/dev/null 2>&1 || { echo 999999; return; }
  _fc="$(gh pr diff "$1" --name-only 2>/dev/null | grep -c . || true)"
  [ -n "$_fc" ] && [ "$_fc" -gt 0 ] 2>/dev/null && echo "$_fc" || echo 999999
}

TMP="$(mktemp -d)" || { echo "rank-pr-candidates: cannot create a temp dir" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT INT TERM

CLASSIFIED=0     # how many PRs we could actually classify (clear or excluded); 0-for-all ⇒ UNKNOWN
for pr in $PRS; do
  classify "$pr"; _cv=$?
  case "$_cv" in
    0) CLASSIFIED=$((CLASSIFIED + 1))
       fc="$(file_count "$pr")"
       printf '%s\t%s\n' "$fc" "$pr" >> "$TMP/eligible" ;;
    1) CLASSIFIED=$((CLASSIFIED + 1))
       echo "rank-pr-candidates: PR #$pr excluded (touches an excluded domain) — never a gap target." >&2 ;;
    *) echo "rank-pr-candidates: PR #$pr could not be classified — dropped (fail closed)." >&2 ;;
  esac
done

# Not a single PR could be classified → we learned nothing about safety. Fail closed as UNKNOWN.
if [ "$CLASSIFIED" -eq 0 ]; then
  echo "rank-pr-candidates: none of the run's PRs could be classified (classifier/gh unavailable)." >&2
  exit 2
fi

if [ ! -s "$TMP/eligible" ]; then
  echo "rank-pr-candidates: no eligible PR — every PR in this run touched an excluded domain."
  exit 1
fi

# Rank by file count ascending (tighter diff first), PR number as a stable tiebreak.
echo "rank-pr-candidates: shortlist (tightest diff first — the model picks the most instructive):"
LC_ALL=C sort -t"$(printf '\t')" -k1,1n -k2,2n "$TMP/eligible" | \
  while IFS="$(printf '\t')" read -r fc pr; do
    [ -n "$pr" ] || continue
    printf '  PR #%s  (%s file(s) changed)\n' "$pr" "$fc"
  done
exit 0
