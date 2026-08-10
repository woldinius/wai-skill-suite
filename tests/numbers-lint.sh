#!/usr/bin/env sh
# numbers-lint.sh — a claim in prose is a claim until something measures it.
#
# Three review rounds in three days each caught the same defect class: a number in prose that a
# rename, a merge or a new file had quietly made false. "199 cases, each one a bug that shipped"
# (it was not), "eight skills read the catalog" (it was nine), "89 IDs / ~440 lines" (91/530),
# "nine reports" (ten, then eleven), and both documented install paths pinned to a tag that was
# never cut. Every one of these was mechanically checkable, and nothing checked — the exact
# failure this repo was built around, one layer up. Filed as issue #7 by the first cold checkout;
# this file is the fix for the class.
#
# WHAT IT CHECKS — only claims with a mechanical ground truth, only in LIVING documents:
#   1. every `vX.Y.Z` in README.md / install.sh exists in `git tag`
#   2. every "<n> IDs … <m> lines" / "<n>-ID" baseline claim matches the measured baseline
#      (IDs exact — counted by catalog-lint itself, the single authority; lines within 10%)
#   3. every "<word> skills read/load …" matches the counted catalog readers
#   4. every "<word> field runs" matches the counted runs in docs/empirics.md
#   5. every "<n> scripts" in README/publication matches the counted suite scripts
#   6. "<n> cases" in the README matches the suites' pass count — ONLY when the caller passes
#      `--cases <n>` (CI does, from the suites it just ran). Without it the check prints SKIP,
#      because a check that did not run is not a check that passed.
#   7. gate-ledger claims ("<n> gate verdicts on record", "<n> GO row(s)", "<n> untagged") match
#      the ledger — counted by gate-stats.sh, the one ledger authority; docs/open-questions.md
#      carries these numbers as a LIVE eval agenda, and live numbers must be re-measured.
#
# Dated evidence is exempt (field reports, audits, empirics, retrospective, history, ADRs,
# proposals): a report is only true as of the moment it ran, and its numbers age WITH it.
# Judgment stays out (ADR-0002): this file compares integers, nothing else.
#
# Exit: 0 every claim matches · 1 a claim is stale · 2 could not measure (not a pass).
set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" 2>/dev/null || { echo "numbers-lint: cannot enter $ROOT" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "numbers-lint: git is required" >&2; exit 2; }

CASES=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --cases)  [ "$#" -ge 2 ] && [ -n "${2:-}" ] || { echo "numbers-lint: --cases needs a number" >&2; exit 2; }
              CASES="$2"; shift 2 ;;
    --cases=) echo "numbers-lint: --cases needs a number" >&2; exit 2 ;;
    --cases=*) CASES="${1#--cases=}"; shift ;;
    *)        echo "numbers-lint: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

FAIL=0
stale() { printf '  STALE %s\n' "$1"; FAIL=$((FAIL+1)); }

# ── ground truths, measured once ────────────────────────────────────────────────────────────────
BASE=".claude/skills/wai-init/references/quality-attributes.baseline.md"
[ -f "$BASE" ] || { echo "numbers-lint: no baseline at $BASE" >&2; exit 2; }

# The ID count comes from catalog-lint — the one authority on what counts as a dimension. A second
# counting method here would be a second copy to drift (the coordination-lint/excluded-domains rule).
IDS="$(sh .claude/skills/wai-init/scripts/catalog-lint.sh "$BASE" 2>/dev/null \
       | grep -oE '[0-9]+ dimensions' | awk '{print $1; exit}')"
[ -n "$IDS" ] || { echo "numbers-lint: catalog-lint did not report a dimension count" >&2; exit 2; }
BASELINES="$(wc -l < "$BASE" | tr -d ' ')"
READERS="$(grep -le 'quality-attributes\.md' .claude/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
RUNS="$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2} · Run ' docs/empirics.md 2>/dev/null || echo 0)"
SCRIPTS="$(find .claude/skills/*/scripts -name '*.sh' -not -path '*/tests/*' 2>/dev/null | wc -l | tr -d ' ')"
# A shallow CI checkout has no tags, and "no tags fetched" must not read as "this tag does not
# exist" — the first CI run of this lint failed on tags that were real. Fall back to asking the
# remote; if THAT also yields nothing, version checks SKIP visibly rather than lie either way.
TAGS="$(git tag 2>/dev/null)"
[ -n "$TAGS" ] || TAGS="$(git ls-remote --tags origin 2>/dev/null | sed 's|.*refs/tags/||; s|\^{}$||' | sort -u)"
TAGS_KNOWN=yes
[ -n "$TAGS" ] || TAGS_KNOWN=no
# Ledger numbers come from gate-stats.sh — the one authority on what counts as a verdict row (the
# same single-parser rule as the ID count above). MERGE_GATE_LEDGER overrides the path, exactly as
# it does for the gate that writes the file — which is also what makes the STALE branch testable.
GLEDGER="${MERGE_GATE_LEDGER:-docs/architecture/gate-ledger.md}"
LEDGER_KNOWN=yes
GSTATS="$(sh .claude/skills/wai-pr-review/scripts/gate-stats.sh "$GLEDGER" 2>/dev/null)" || LEDGER_KNOWN=no
LROWS="$(printf '%s\n' "$GSTATS" | grep -oE '[0-9]+ verdict' | awk '{print $1; exit}')"
[ -n "$LROWS" ] || LROWS=0
LGO="$(printf '%s\n' "$GSTATS" | sed -n 's/^ *GO \([0-9]\{1,\}\) .*/\1/p' | head -1)"
[ -n "$LGO" ] || LGO=0
LUNTAGGED="$(printf '%s\n' "$GSTATS" | sed -n 's/^ *\([0-9]\{1,\}\) still untagged.*/\1/p' | head -1)"
[ -n "$LUNTAGGED" ] || LUNTAGGED=0

word_for() {  # small on purpose: outside this range, print the digit and let the mismatch show
  case "$1" in
    6) echo six ;; 7) echo seven ;; 8) echo eight ;; 9) echo nine ;; 10) echo ten ;;
    11) echo eleven ;; 12) echo twelve ;; *) echo "$1" ;;
  esac
}
WORD_RE='six|seven|eight|nine|ten|eleven|twelve'

# Living documents: what a reader is asked to believe TODAY. `git ls-files` so an untracked draft
# never fails a build it is not part of.
LIVING="$(git ls-files 'README.md' 'install.sh' '.claude/skills/**' 'docs/publication/**' \
                       'docs/learnings/README.md' 'docs/architecture/quality-attributes.md' \
                       'docs/architecture/testing-strategy.md' 'docs/open-questions.md' \
             | grep -vE '/tests/')"

for f in $LIVING; do
  [ -f "$f" ] || continue
  # Flatten so a claim wrapped across a line break ("nine\n  skills") is still one claim.
  FLAT="$(tr '\n' ' ' < "$f" | tr -s ' ')"

  # 1 · version references (README + install.sh only — the two files that tell people what to fetch)
  case "$f" in
    README.md|install.sh)
      if [ "$TAGS_KNOWN" = yes ]; then
        for v in $(printf '%s' "$FLAT" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sort -u); do
          printf '%s\n' "$TAGS" | grep -qxF "$v" \
            || stale "$f: references $v, but \`git tag\` does not know it — a reader following this gets a 404"
        done
      fi ;;
  esac

  # 2 · baseline claims: "<n> IDs … <m> lines" (both together = a claim about the bundled baseline)
  #     and the "<n>-ID" shorthand. "55 of 89" incident history matches neither pattern, on purpose.
  for pair in $(printf '%s' "$FLAT" | grep -oE '[0-9]+ IDs[,/ ]+ ?~?[0-9]+ lines' | tr ' ' '_'); do
    n="$(printf '%s' "$pair" | grep -oE '^[0-9]+')"
    m="$(printf '%s' "$pair" | grep -oE '[0-9]+_lines' | grep -oE '[0-9]+')"
    [ "$n" = "$IDS" ] || stale "$f: claims $n IDs, baseline has $IDS"
    lo=$((BASELINES * 90 / 100)); hi=$((BASELINES * 110 / 100))
    { [ "$m" -ge "$lo" ] && [ "$m" -le "$hi" ]; } \
      || stale "$f: claims ~$m lines, baseline has $BASELINES (outside 10%)"
  done
  for n in $(printf '%s' "$FLAT" | grep -oE '[0-9]+-ID[ .,)]' | grep -oE '[0-9]+'); do
    [ "$n" = "$IDS" ] || stale "$f: claims a $n-ID document, baseline has $IDS"
  done

  # 3 · who reads the catalog ("nine skills read/load …") — the count that had five answers once
  for w in $(printf '%s' "$FLAT" | grep -oiE "($WORD_RE) skills (read|load)" | awk '{print tolower($1)}'); do
    [ "$w" = "$(word_for "$READERS")" ] \
      || stale "$f: says '$w skills' read the catalog, counted $READERS"
  done

  # 4 · field runs in the running record
  for w in $(printf '%s' "$FLAT" | grep -oiE "($WORD_RE) field runs" | awk '{print tolower($1)}'); do
    [ "$w" = "$(word_for "$RUNS")" ] \
      || stale "$f: says '$w field runs', docs/empirics.md has $RUNS"
  done

  # 5 · suite script count (README + publication only; a skill talking about ITS scripts is fine)
  case "$f" in
    README.md|docs/publication/*)
      for n in $(printf '%s' "$FLAT" | grep -oE '[0-9]+ scripts' | grep -oE '[0-9]+'); do
        [ "$n" = "$SCRIPTS" ] || stale "$f: claims $n scripts, counted $SCRIPTS"
      done ;;
  esac

  # 7 · gate-ledger claims — the open-questions agenda carries these as LIVE numbers, so they are
  #     held to the ledger on every run. (NO-GO must never count as GO: the hyphen keeps the
  #     pattern from matching inside "NO-GO", and the fixture test proves it stays that way.)
  if [ "$LEDGER_KNOWN" = yes ]; then
    for n in $(printf '%s' "$FLAT" | grep -oE '[0-9]+ gate verdicts? on record' | grep -oE '^[0-9]+'); do
      [ "$n" = "$LROWS" ] || stale "$f: claims $n gate verdicts on record, the ledger has $LROWS"
    done
    for n in $(printf '%s' "$FLAT" | grep -oE '[0-9]+ GO rows?' | grep -oE '^[0-9]+'); do
      [ "$n" = "$LGO" ] || stale "$f: claims $n GO row(s), the ledger has $LGO"
    done
    for n in $(printf '%s' "$FLAT" | grep -oE '[0-9]+ untagged' | grep -oE '^[0-9]+'); do
      [ "$n" = "$LUNTAGGED" ] || stale "$f: claims $n untagged row(s), the ledger has $LUNTAGGED"
    done
  fi
done

[ "$TAGS_KNOWN" = yes ] \
  || echo "  SKIP  version references not verified (no tags locally or from origin) — a skipped check is not a pass"
[ "$LEDGER_KNOWN" = yes ] \
  || echo "  SKIP  gate-ledger claims not verified (no readable ledger at $GLEDGER) — a skipped check is not a pass"

# 6 · the README's test-case count, against the run the caller just made
CLAIMED_CASES="$(tr '\n' ' ' < README.md | grep -oE '[0-9]+ cases' | grep -oE '[0-9]+' | sort -u)"
if [ -n "$CASES" ]; then
  for n in $CLAIMED_CASES; do
    [ "$n" = "$CASES" ] || stale "README.md: claims $n cases, the suites just passed $CASES"
  done
elif [ -n "$CLAIMED_CASES" ]; then
  echo "  SKIP  README case count not verified (no --cases given) — a skipped check is not a pass"
fi

if [ "$FAIL" -gt 0 ]; then
  echo "numbers-lint: $FAIL stale claim(s). A number nothing re-measures is a claim, not a fact."
  exit 1
fi
echo "numbers-lint: every measurable claim matches its measurement (baseline $IDS/$BASELINES, readers $READERS, runs $RUNS, scripts $SCRIPTS, ledger $LROWS/$LGO)."
exit 0
