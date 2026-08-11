#!/usr/bin/env sh
# mine-issues.sh — the read-only signal an existing backlog already carries about THIS repo.
#
# wai-init writes a quality catalog. Left to a cold read of the code, it proposes the dimensions
# the code SHAPE suggests — and misses the ones the team has been feeling for months but that leave no
# structural trace: the label people keep reaching for, the word that recurs across a dozen bug
# titles, the theme half the closed PRs share. That history is evidence, and evidence a catalog author
# never sees is a catalog dimension never written. This script surfaces it — as COUNTS the model then
# judges, never as a verdict.
#
# WHAT IT EMITS (and nothing more):
#   LABEL_FREQ         — how often each issue label is used, with up to 3 example issue NUMBERS.
#   TERM_DF            — recurring words by DOCUMENT FREQUENCY (how many issues mention the term, not
#                        how many times), with up to 3 example NUMBERS. DF, not raw count, is the honest
#                        signal: one issue that says "timeout" nine times is one team pain, not nine.
#   CLOSED_PR_THEMES   — the labels and title terms that recur across CLOSED PRs — what the team has
#                        actually been merging fixes FOR.
#
# WHAT IT REFUSES TO DO — and why the refusal is the point:
#   * It prints NUMBERS, never bodies. An issue body is the most PII-dense text in a repo (stack traces
#     with usernames, customer emails, tokens pasted in a hurry). Mining it wholesale into a catalog
#     proposal would launder that PII into a committed doc. Bodies are read ONLY behind --bodies, ONLY
#     to widen the TERM_DF corpus, and every email-shaped token is redacted before it is ever tokenised.
#   * It does NOT decide whether a signal is a real quality concern, nor whether to extend a dimension,
#     mint a new local ID (>=100), propose it upstream, or drop it. That is model judgment on LOCAL
#     ID space (ADR-0003: an ID inside an issue resolves against THIS repo's catalog, never a baseline).
#
#   exit 0  signals emitted (an EMPTY backlog is valid — a new repo has no history, and says so)
#   exit 2  UNKNOWN: gh missing / unauthenticated / the origin is not a GitHub repo gh can resolve.
#           Not a failure of THIS repo — a failure to reach the signal. The caller degrades to
#           code-only mining and records the gap. (2 is the suite's UNKNOWN across the gh emitters.)
#   (There is deliberately no exit 3. "You ran me in the wrong place" and "I could not reach
#   GitHub" are different FACTS, but they are the same DECISION for the caller: do not trust the
#   mining, fall back to code-only. The distinction belongs in the message, not the exit code —
#   and the suite's precedent is settled: excluded-domains.sh and merge-gate.sh both map misuse
#   to 2. A private fourth code makes every caller learn a per-script dialect.)
#
# Usage: sh mine-issues.sh [--since YYYY-MM-DD] [--limit N] [--bodies]
#        (default: --limit 200, all dates, titles+labels only)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX word-split + pattern semantics

SINCE=""
LIMIT="200"
BODIES="no"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --since) SINCE="${2:-}"; shift 2 ;;
    --since=*) SINCE="${1#--since=}"; shift ;;
    --limit) LIMIT="${2:-200}"; shift 2 ;;
    --limit=*) LIMIT="${1#--limit=}"; shift ;;
    --bodies) BODIES="yes"; shift ;;
    -h|--help) echo "usage: sh mine-issues.sh [--since YYYY-MM-DD] [--limit N] [--bodies]"; exit 0 ;;
    *) echo "mine-issues: unknown argument '$1' — cannot mine (UNKNOWN)." >&2; exit 2 ;;
  esac
done
case "$LIMIT" in ''|*[!0-9]*) LIMIT="200" ;; esac

# --- Preconditions, in the order that tells the caller WHAT to do next ---------------------------
# Not a git repo → UNKNOWN (2): the caller invoked us in the wrong place. The MESSAGE says which;
# the code says what to do about it — the same thing either way: degrade to code-only mining.
git rev-parse --git-dir >/dev/null 2>&1 || { echo "mine-issues: not a git repository — nothing to mine (UNKNOWN)." >&2; exit 2; }

# gh missing / unauthenticated / non-GitHub origin → exit 2 (UNKNOWN). The signal is unreachable, not
# absent; the caller degrades to code-only mining and notes the gap, rather than reading silence as a
# clean backlog.
command -v gh >/dev/null 2>&1 || { echo "mine-issues: gh is not installed — degrade to code-only mining (issue/PR history unread)." >&2; exit 2; }
gh auth status >/dev/null 2>&1 || { echo "mine-issues: gh is not authenticated — degrade to code-only mining (issue/PR history unread)." >&2; exit 2; }
gh repo view --json nameWithOwner >/dev/null 2>&1 || { echo "mine-issues: origin is not a GitHub repo gh can resolve — degrade to code-only mining." >&2; exit 2; }

TAB=$(printf '\t')
NOW="$(date -u +%Y-%m-%dT%H:%MZ 2>/dev/null || echo '?')"

# gh search qualifier for --since (created on/after the date). Empty ⇒ no date filter.
SEARCH=""
[ -n "$SINCE" ] && SEARCH="created:>=$SINCE"

# Stopwords + the token filter, inline (no temp file, no external wordlist to drift). Short tokens,
# pure numbers and these function words carry no catalog signal — dropping them is what turns a word
# cloud into a shortlist.
STOP='the|and|for|are|but|not|you|all|any|can|had|her|was|one|our|out|has|him|his|how|new|now|old|see|two|way|who|did|its|let|put|say|she|too|use|this|that|with|from|have|will|your|they|them|then|than|when|what|which|were|been|into|also|some|such|only|very|just|able|does|done|each|more|most|much|over|same|both|via|per|get|set|add|fix|bug|off|our|why|yet'

# tokenise STDIN into unique-per-record tokens, tagging each with the record NUMBER read on $1's
# first TSV field. Emits `token<TAB>number`, one line per (token, issue) pair, deduped within the
# issue so the downstream tally is a DOCUMENT frequency, not a raw word count.
emit_terms() {   # reads "number<TAB>text" lines on stdin
  while IFS="$TAB" read -r _num _text; do
    [ -n "$_num" ] || continue
    printf '%s\n' "$_text" \
      | sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z][A-Za-z]+/ /g' \
      | tr '[:upper:]' '[:lower:]' \
      | tr -cs 'a-z0-9' '\n' \
      | grep -E '^.{3,}$' \
      | grep -vE '^[0-9]+$' \
      | grep -vE "^($STOP)$" \
      | sort -u \
      | while IFS= read -r _tok; do [ -n "$_tok" ] && printf '%s\t%s\n' "$_tok" "$_num"; done
  done
}

# tally `key<TAB>number` pairs → "count<TAB>key<TAB>#a,#b,#c", most frequent first, capped.
tally() {   # $1 = cap (max rows)
  awk -F'\t' '
    { c[$1]++; if (n[$1] < 3) { ex[$1] = ex[$1] (ex[$1]=="" ? "" : ",") "#" $2; n[$1]++ } }
    END { for (k in c) printf "%d\t%s\t%s\n", c[k], k, ex[k] }' \
  | sort -rn -k1,1 | head -n "$1"
}

echo "# mine-issues $NOW  (limit=$LIMIT${SINCE:+, since=$SINCE}, bodies=$BODIES)"
echo "# COUNTS are evidence, not a verdict. The model judges extend/mint(>=100)/upstream/drop per ADR-0003;"
echo "#   an ID inside an issue resolves against THIS repo's catalog, never a baseline number."
echo

# --- LABEL_FREQ ---------------------------------------------------------------------------------
echo "## LABEL_FREQ"
# shellcheck disable=SC2016  # $n is a jq variable inside gh's --jq program, not a shell expansion
LBL="$(gh issue list --state all --limit "$LIMIT" ${SEARCH:+--search "$SEARCH"} \
        --json number,labels \
        --jq '.[] | .number as $n | (.labels[]?.name) | [ ., ($n|tostring) ] | @tsv' 2>/dev/null || true)"
if [ -n "$LBL" ]; then
  printf '%s\n' "$LBL" | tally 40 \
    | while IFS="$TAB" read -r _c _label _ex; do
        printf 'LABEL_FREQ label="%s" count=%s examples=%s\n' "$_label" "$_c" "$_ex"
      done
else
  echo "LABEL_FREQ (none — no labelled issues in range)"
fi
echo

# --- TERM_DF ------------------------------------------------------------------------------------
echo "## TERM_DF"
if [ "$BODIES" = "yes" ]; then
  # Bodies widen the corpus. Emails are redacted BEFORE tokenising (see emit_terms); no body text is
  # ever printed — only the derived token counts and issue numbers.
  TITLES="$(gh issue list --state all --limit "$LIMIT" ${SEARCH:+--search "$SEARCH"} \
             --json number,title,body \
             --jq '.[] | [ (.number|tostring), (.title + " " + (.body // "")) ] | @tsv' 2>/dev/null || true)"
else
  TITLES="$(gh issue list --state all --limit "$LIMIT" ${SEARCH:+--search "$SEARCH"} \
             --json number,title \
             --jq '.[] | [ (.number|tostring), .title ] | @tsv' 2>/dev/null || true)"
fi
if [ -n "$TITLES" ]; then
  printf '%s\n' "$TITLES" | emit_terms | tally 25 \
    | while IFS="$TAB" read -r _df _term _ex; do
        printf 'TERM_DF term="%s" df=%s examples=%s\n' "$_term" "$_df" "$_ex"
      done
else
  echo "TERM_DF (none — no issues in range)"
fi
echo

# --- CLOSED_PR_THEMES ---------------------------------------------------------------------------
echo "## CLOSED_PR_THEMES"
# shellcheck disable=SC2016  # $n is a jq variable inside gh's --jq program, not a shell expansion
PRLBL="$(gh pr list --state closed --limit "$LIMIT" ${SEARCH:+--search "$SEARCH"} \
          --json number,labels \
          --jq '.[] | .number as $n | (.labels[]?.name) | [ ., ($n|tostring) ] | @tsv' 2>/dev/null || true)"
PRTITLE="$(gh pr list --state closed --limit "$LIMIT" ${SEARCH:+--search "$SEARCH"} \
            --json number,title \
            --jq '.[] | [ (.number|tostring), .title ] | @tsv' 2>/dev/null || true)"
if [ -n "$PRLBL" ] || [ -n "$PRTITLE" ]; then
  [ -n "$PRLBL" ] && printf '%s\n' "$PRLBL" | tally 25 \
    | while IFS="$TAB" read -r _c _label _ex; do
        printf 'CLOSED_PR_THEMES label="%s" count=%s examples=%s\n' "$_label" "$_c" "$_ex"
      done
  [ -n "$PRTITLE" ] && printf '%s\n' "$PRTITLE" | emit_terms | tally 25 \
    | while IFS="$TAB" read -r _df _term _ex; do
        printf 'CLOSED_PR_THEMES term="%s" df=%s examples=%s\n' "$_term" "$_df" "$_ex"
      done
else
  echo "CLOSED_PR_THEMES (none — no closed PRs in range)"
fi

echo
echo "# done. Each signal above is a CANDIDATE for the catalog author to weigh — not a dimension."
exit 0
