#!/usr/bin/env sh
# tests/run.sh — the two scripts that decide everything, tested.
#
# `merge-gate.sh` and `catalog-lint.sh` are the ONLY deterministic things in this suite. Everything
# else is a prompt. If they are wrong, the thesis is wrong — and in the two days after they shipped
# they took NINE repair commits, every bug found by running them by hand against a live repo.
#
# What that cost, and what this file exists to stop:
#   · The gate could never say GO in any repo: it read SKIPPED as a failure, and the suite's own CI
#     template ships a job that is skipped on every PR. Five field runs, and nobody could tell,
#     because a NO-GO looks exactly like a NO-GO.
#   · shellcheck PASSED a `case … esac` inside `$( )` — a syntax error in bash 3.2, which is what
#     /bin/sh IS on macOS. shellcheck is not a test.
#   · The lint could only ever fail in the repo it was written in.
#   · Four of my own ad-hoc harnesses were themselves broken (exit code read through a pipe, twice).
#
# AND THE CASE NOBODY WRITES. Everyone tests that a gate BLOCKS — the easy path, and the one that
# fails safe: a wrong answer there costs a human one click. Almost nobody tests that it PASSES,
# and the pass path carries the gate's ENTIRE value. Case 1 below is "green repo → GO", and it is
# first on purpose:
#
#   A gate you have never seen say GO is not a validated gate. It is an untested branch that
#   happens to be failing closed.
#
# This suite ran one of those for months, in two repos.
#
# Every case below exists because something broke, or to keep it from breaking again — the file
# was FOUNDED on shipped bugs, and it is not true that every case is one (the retrospective records
# that overclaim, in my words: "It is 8 of 29"). Run: sh tests/run.sh
# shellcheck disable=SC2016,SC2013  # the backticks in the fixtures are catalog citations, not
# expansions — they are precisely what is under test.
set -u
[ -n "${ZSH_VERSION:-}" ] && exec /bin/sh "$0" "$@"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/.claude/skills/wai-pr-review/scripts/merge-gate.sh"
LINT="$ROOT/.claude/skills/wai-init/scripts/catalog-lint.sh"
STUB="$ROOT/tests/stub"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

PASS=0; FAIL=0; SKIP=0; N=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n         %s\n' "$1" "$2"; }
# A check that did not run is not a check that passed. It gets its own verb and its own counter,
# because the first version of the YAML guard reported its own absence as `ok` — a green line for
# a test that never executed, in the very file whose header calls that the worst kind of green.
skip() { SKIP=$((SKIP+1)); printf '  SKIP %s\n' "$1"; }

# assert NAME WANT-EXIT GOT-EXIT OUTPUT [MUST-MATCH] [MUST-NOT-MATCH]
assert() {
  _n="$1"; _we="$2"; _ge="$3"; _out="$4"; _m="${5:-}"; _x="${6:-}"; _why=""
  if   [ "$_ge" != "$_we" ];                                       then _why="exit $_ge, wanted $_we"
  elif [ -n "$_m" ] && ! printf '%s\n' "$_out" | grep -qE "$_m";   then _why="no match for /$_m/"
  elif [ -n "$_x" ] &&   printf '%s\n' "$_out" | grep -qE "$_x";   then _why="matched /$_x/ and must not"
  fi
  if [ -z "$_why" ]; then ok "$_n"; else
    bad "$_n" "$_why"; printf '%s\n' "$_out" | sed 's/^/         | /'
  fi
}

# ── merge-gate.sh ───────────────────────────────────────────────────────────────────────────────
# A fresh fixture is a GREEN, solo repo: two required checks, both SUCCESS, an innocuous file.
gfix() {
  N=$((N+1)); D="$TMP/g$N"; mkdir -p "$D/docs/architecture"
  printf '# Q\n\n**Repo mode:** solo\n\n- **SEC-1 · Auth** — a. *Red Flag:* b.\n' > "$D/docs/architecture/quality-attributes.md"
  printf 'CONTRACT_PATHS="apps/api/src/billing/* apps/api/src/auth/*"\nMIGRATION_PATHS="migrations/*"\n' > "$D/docs/architecture/merge-gate.conf"
  printf 'acme/repo\n'                        > "$D/repo"
  printf 'main\n'                             > "$D/base"
  printf 'README.md\n'                        > "$D/files"
  printf '1\n'                                > "$D/ruleset-ids"
  printf 'test\nsize-gate\n'                  > "$D/required"
  printf 'SUCCESS\ttest\nSUCCESS\tsize-gate\n' > "$D/checks"
  printf 'OPEN\n'                             > "$D/state"
  : > "$D/diff"
}
gate() { ( cd "$D" && PATH="$STUB:$PATH" GH_FIXTURE="$D" sh "$GATE" 1 2>&1 ); }

echo "merge-gate.sh"

gfix; out="$(gate)"; rc=$?
assert "green repo → GO" 0 "$rc" "$out" 'VERDICT: GO'

# THE BUG THAT SHIPPED. A skipped job is not a failed one, and it is not required.
gfix; printf 'SUCCESS\ttest\nSUCCESS\tsize-gate\nSKIPPED\tbuild-push\n' > "$D/checks"
out="$(gate)"; rc=$?
assert "a NON-required SKIPPED check does not block" 0 "$rc" "$out" 'VERDICT: GO'

# AND THE TRAP IN THE OBVIOUS FIX. "SKIPPED = green" would let a suppressed required check through.
gfix; printf 'SKIPPED\ttest\nSUCCESS\tsize-gate\n' > "$D/checks"
out="$(gate)"; rc=$?
assert "a REQUIRED SKIPPED check is skip-to-green → NO-GO" 1 "$rc" "$out" 'test=SKIPPED'

gfix; printf 'SUCCESS\tsize-gate\n' > "$D/checks"
out="$(gate)"; rc=$?
assert "a required check that never reported → NO-GO" 1 "$rc" "$out" 'test=DID-NOT-REPORT'

gfix; printf 'SUCCESS\ttest\nSUCCESS\tsize-gate\nFAILURE\tcoverage-bot\n' > "$D/checks"
out="$(gate)"; rc=$?
assert "a non-required FAILURE is stated, never a veto" 0 "$rc" "$out" 'coverage-bot=FAILURE.*|VERDICT: GO'

# Word-splitting: `for r in $REQUIRED` turns this into two checks that never reported.
gfix; printf 'Lint (all workspaces)\n' > "$D/required"
printf 'SUCCESS\tLint (all workspaces)\n' > "$D/checks"
out="$(gate)"; rc=$?
assert "a check name with spaces survives" 0 "$rc" "$out" 'VERDICT: GO'

# Required set unreadable → strict rule. And gh's 404 body must never become a check name.
gfix; : > "$D/rulesets-403"; rm -f "$D/ruleset-ids"
printf 'SUCCESS\ttest\nSKIPPED\tbuild-push\n' > "$D/checks"
out="$(gate)"; rc=$?
assert "unreadable required set → strict, fail-closed" 1 "$rc" "$out" 'no required status checks' 'Branch not protected|message'

gfix; : > "$D/checks"
out="$(gate)"; rc=$?
assert "zero checks is not green" 1 "$rc" "$out" 'zero checks'

# The guardrail floor: the agent may not merge a change to the standard it is judged against.
gfix; printf '.claude/skills/wai/SKILL.md\n' > "$D/files"
out="$(gate)"; rc=$?
assert "touching the suite's guardrails → NO-GO" 1 "$rc" "$out" 'EX-GUARD'

gfix; printf 'apps/api/src/billing/tokens.ts\n' > "$D/files"
out="$(gate)"; rc=$?
assert "touching a contract domain → NO-GO" 1 "$rc" "$out" 'EX-PAY'

gfix; rm -f "$D/docs/architecture/merge-gate.conf"
out="$(gate)"; rc=$?
assert "no merge-gate.conf → UNKNOWN, never GO" 2 "$rc" "$out" 'merge-gate.conf'

gfix; rm -f "$D/docs/architecture/quality-attributes.md"
out="$(gate)"; rc=$?
assert "no catalog → NO-GO" 1 "$rc" "$out" 'wai-init'

# A TOOL FAILURE IS NOT A VERDICT. Both lines used to be unguarded under `set -e`, so gh's exit 1
# became the gate's exit 1 — NO-GO — for a PR it had never looked at. Field case: `origin` pointed at
# a repo the human had lost access to. The output must not read as a judgment either: a human who
# sees "NO-GO" learns to discount the state that protects `main`.
gfix; : > "$D/repo-fail"
out="$(gate)"; rc=$?
assert "unresolvable repository → UNKNOWN, never NO-GO" 2 "$rc" "$out" 'TOOL failure, not a verdict' 'VERDICT: (GO|NO-GO)'

gfix; : > "$D/base-fail"
out="$(gate)"; rc=$?
assert "unresolvable PR → UNKNOWN, never NO-GO" 2 "$rc" "$out" 'TOOL failure, not a verdict' 'VERDICT: (GO|NO-GO)'

# gh SUCCEEDING while printing nothing is the same hole one layer down — the class the dependency
# scan already taught us: empty output reads as "fine" unless someone checks that it ran.
gfix; rm -f "$D/repo"
out="$(gate)"; rc=$?
assert "repo lookup that printed NOTHING → UNKNOWN (not an empty repo name)" 2 "$rc" "$out" 'printed nothing'

# The override is the actual fix: say which repo instead of guessing from a remote.
gfix; : > "$D/repo-fail"
out="$( cd "$D" && PATH="$STUB:$PATH" GH_FIXTURE="$D" sh "$GATE" 1 --repo acme/repo 2>&1 )"; rc=$?
assert "--repo bypasses the remote guess entirely → GO" 0 "$rc" "$out" 'VERDICT: GO'

# And a --repo with no value must NOT quietly become "guess from the remote". That is the exact
# situation the flag was added for — a dead `origin`, the work on a second remote — so falling
# back would restore the failure while looking like the selector was honoured.
gfix; : > "$D/repo-fail"
out="$( cd "$D" && PATH="$STUB:$PATH" GH_FIXTURE="$D" sh "$GATE" 1 --repo 2>&1 )"; rc=$?
assert "--repo with no value → UNKNOWN, never a silent remote fallback" 2 "$rc" "$out" 'needs a value'
out="$( cd "$D" && PATH="$STUB:$PATH" GH_FIXTURE="$D" sh "$GATE" 1 --repo= 2>&1 )"; rc=$?
assert "--repo= with an empty value → UNKNOWN too" 2 "$rc" "$out" 'needs a value'

gfix; : > "$D/repo-fail"
out="$( cd "$D" && PATH="$STUB:$PATH" GH_FIXTURE="$D" GH_REPO=acme/repo sh "$GATE" 1 2>&1 )"; rc=$?
assert "\$GH_REPO does the same → GO" 0 "$rc" "$out" 'VERDICT: GO'

gfix
out="$( cd "$D" && PATH="$STUB:$PATH" GH_FIXTURE="$D" sh "$GATE" 1 --bogus 2>&1 )"; rc=$?
assert "an unknown option is UNKNOWN, never a silent GO" 2 "$rc" "$out" 'unknown option'

# THE GATE'S ONE FAIL-OPEN PATH. merge-gate gained --repo and threaded it through every check it
# makes ITSELF — then delegated the domain classification with only `--pr <n>`, so the classifier
# resolved the diff from the LOCAL remote. Against a checkout whose origin points elsewhere (the
# field case that produced --repo), the gate judged repo A while the classifier read repo B's PR of
# the same number, and reported CLEAR on a diff it had never seen. Every other unresolvable state in
# that script returns 2 and holds; this one returned "clean". Assert the ARGUMENTS, not the answer —
# the answer looked right precisely because the stub only knows one repo.
gfix; gate >/dev/null 2>&1
if grep -q 'pr diff 1 --name-only --repo acme/repo' "$D/gh-calls.log" 2>/dev/null; then
  ok "the gate passes its resolved repo INTO the delegated classifier"
else
  bad "the gate passes its resolved repo INTO the delegated classifier" \
      "no 'gh pr diff … --repo' in the stub's call log — the classifier fell back to the local remote"
fi

# The ledger: the gate must EMIT its verdict — the denominator has to be written by the script, not
# by a human who remembers. Assert through the real path (the gate actually ran above), and assert
# the emission cannot change the verdict: a read-only ledger dir still returns GO, not an error.
gfix; gate >/dev/null 2>&1
LED="$D/docs/architecture/gate-ledger.md"
if [ -f "$LED" ] && grep -qE '^\| .* \| 1 \| GO \|' "$LED"; then ok "a GO run appends a GO row to the ledger"
else bad "a GO run appends a GO row to the ledger" "no GO row in $LED"; fi
if grep -q 'APPEND-ONLY' "$LED" 2>/dev/null; then ok "a fresh ledger writes its own tagging protocol"
else bad "a fresh ledger writes its own tagging protocol" "no self-documenting header"; fi
# The run-log self-log site (issue #11): a gate verdict IS a wai-pr-review run and the mapping is
# 1:1, so the SCRIPT writes the attendance row beside the ledger row. The gate ran in the fixture's
# cwd, so the row must land in the FIXTURE's docs/ — never in this repo.
RLOG="$D/docs/architecture/run-log.md"
if grep -qF '| wai-pr-review | PR #1 | GO |' "$RLOG" 2>/dev/null; then
  ok "a GO run also appends a run-log row (skill=wai-pr-review, outcome=the verdict label)"
else bad "a GO run also appends a run-log row" "no wai-pr-review GO row in $RLOG"; fi
if grep -q 'A run without a row is invisible work' "$RLOG" 2>/dev/null; then
  ok "a fresh run log writes its own self-documenting header"
else bad "a fresh run log writes its own self-documenting header" "no #11 header in $RLOG"; fi

gfix; MERGE_GATE_LEDGER=/proc/nonexistent/x/gate.md
out="$( cd "$D" && PATH="$STUB:$PATH" GH_FIXTURE="$D" MERGE_GATE_LEDGER="$MERGE_GATE_LEDGER" sh "$GATE" 1 2>&1 )"; rc=$?
assert "an unwritable ledger does NOT change the verdict (fail-open logging)" 0 "$rc" "$out" 'VERDICT: GO'
unset MERGE_GATE_LEDGER

# Post-merge = MOOT. A gate run on an already-merged PR must say so, not fake a GO/NO-GO — no
# artefact watches ordering, and this is the one place the gate can. It must short-circuit BEFORE
# the guardrail/contract checks (which are irrelevant once merged) and record a MOOT row, so an
# absent row never reads as "never checked". (Field report: a production iOS repo — merged before its review ran.)
gfix; printf 'MERGED\n' > "$D/state"; printf '.claude/skills/wai/SKILL.md\n' > "$D/files"
out="$(gate)"; rc=$?
assert "an already-merged PR → MOOT (not GO/NO-GO), exit 2" 2 "$rc" "$out" 'VERDICT: MOOT' 'VERDICT: (GO|NO-GO)'
if grep -qE '^\| .* \| 1 \| MOOT \|' "$D/docs/architecture/gate-ledger.md" 2>/dev/null; then ok "a MOOT run records a MOOT ledger row (absent row would read as never-checked)"
else bad "a MOOT run records a MOOT ledger row" "no MOOT row in the ledger"; fi
if grep -qF '| wai-pr-review | PR #1 | MOOT |' "$D/docs/architecture/run-log.md" 2>/dev/null; then
  ok "the MOOT short-circuit still writes its run-log row (checked-too-late is a run, not a gap)"
else bad "the MOOT short-circuit still writes its run-log row" "no MOOT row in the fixture's run log"; fi

# The why-cell must not be amputated silently. The first cap was `cut -c1-160`, and the ledger's
# first real row ended mid-token ("test (ubuntu-") — a cut that read like the full reason. The cell
# now caps at 400 chars on a word boundary with a visible '…', and the row stays ONE line, because
# gate-stats's awk and the human's outcome tagging both key on one-row-per-verdict.
gfix
for i in 1 2 3 4 5; do
  printf 'a-very-long-required-check-name-that-goes-on-and-on-number-%s (matrix, os-variant, extra-qualifier)\n' "$i"
done > "$D/required"
printf 'SUCCESS\tsomething-else\n' > "$D/checks"
out="$(gate)"; rc=$?
row="$(grep -E '^\| [0-9]' "$D/docs/architecture/gate-ledger.md" 2>/dev/null | tail -1)"
cell="$(printf '%s\n' "$row" | awk -F'|' '{print $5}')"
clen="$(printf '%s' "$cell" | wc -m | tr -d ' ')"
if [ "$clen" -gt 300 ] && [ "$clen" -lt 450 ]; then ok "the ledger why-cell outgrew the old 160-char amputation and is still capped"
else bad "the ledger why-cell outgrew the old 160-char amputation and is still capped" "cell length $clen in: $row"; fi
case "$cell" in
  *…*) ok "an over-long reason is cut at a word boundary with a visible ellipsis" ;;
  *)   bad "an over-long reason is cut at a word boundary with a visible ellipsis" "no … in: $cell" ;;
esac

# VERDICT REASONS FIRST IN THE CELL. The cap cuts from the RIGHT, and the reasons used to arrive
# preamble-first — field-measured at a median 143 characters of "✓ everything fine" before the
# first ✗ (issue #10), so what the cap ate was systematically the EX-* ID the verdict hinged on,
# and the human rebuilt the domain names by hand. The cell is reordered at assembly time only:
# ✗/? first, ✓/· after — while the TERMINAL output keeps its natural check order, because a human
# watching the run reads the checks in the order they ran.
gfix; printf 'apps/api/src/billing/tokens.ts\n' > "$D/files"
out="$(gate)"; rc=$?
row="$(grep -E '^\| [0-9]' "$D/docs/architecture/gate-ledger.md" 2>/dev/null | tail -1)"
cell="$(printf '%s\n' "$row" | awk -F'|' '{print $5}')"
case "$cell" in
  ' ✗ touches an excluded domain'*) ok "a NO-GO ledger cell leads with the ✗ reason, ✓ preamble after" ;;
  *) bad "a NO-GO ledger cell leads with the ✗ reason, ✓ preamble after" "cell starts: $(printf '%s' "$cell" | cut -c1-72)" ;;
esac
first80="$(printf '%s' "$cell" | cut -c1-80)"
case "$first80" in
  *EX-*) ok "the EX-* IDs sit within the first 80 characters of the why cell (issue #8 acceptance)" ;;
  *)     bad "the EX-* IDs sit within the first 80 characters of the why cell (issue #8 acceptance)" "first 80: $first80" ;;
esac
if grep -qF '| wai-pr-review | PR #1 | NO-GO |' "$D/docs/architecture/run-log.md" 2>/dev/null; then
  ok "a NO-GO run's run-log row carries the verdict label as its outcome"
else bad "a NO-GO run's run-log row carries the verdict label" "no NO-GO row in the fixture's run log"; fi
lok="$(printf '%s\n' "$out" | grep -n 'quality catalog present' | head -1 | cut -d: -f1)"
lxx="$(printf '%s\n' "$out" | grep -n 'touches an excluded domain' | head -1 | cut -d: -f1)"
if [ -n "$lok" ] && [ -n "$lxx" ] && [ "$lok" -lt "$lxx" ]; then
  ok "the terminal output keeps its natural check order — only the ledger cell is reordered"
else
  bad "the terminal output keeps its natural check order — only the ledger cell is reordered" "✓ at line ${lok:-none}, ✗ at line ${lxx:-none}"
fi

# gate-stats.sh: it counts what the script emitted and what the human tagged — nothing more.
STATS="$ROOT/.claude/skills/wai-pr-review/scripts/gate-stats.sh"
N=$((N+1)); SD="$TMP/s$N"; mkdir -p "$SD"
{ printf '| when | PR | verdict | why | outcome |\n|---|---|---|---|---|\n'
  printf '| 2026-07-16T09:00Z | 1 | NO-GO | x | fp |\n'
  printf '| 2026-07-16T10:00Z | 2 | GO | x | fn |\n'
  printf '| 2026-07-16T11:00Z | 3 | GO | x | ok |\n'; } > "$SD/led.md"
out="$(sh "$STATS" "$SD/led.md" 2>&1)"; rc=$?
assert "gate-stats counts the false negative that makes the case" 0 "$rc" "$out" 'FALSE NEGATIVES[^0-9]*1'
assert "gate-stats reports the 3 emitted verdicts as the denominator" 0 "$rc" "$out" '3 verdict'

# THE 0% THAT WAS 15%. A three-week field ledger (issue #10) tagged with a vocabulary finer than
# two letters — `ok, besser GO`, `ok, manual fix`, `fp, bug` — and the literal-match parser
# silently dropped 20 of 52 judged NO-GO rows, printing a false-positive rate of 0% in the very
# line meant to prove the gate trustworthy. This fixture is that ledger's tag vocabulary, count
# for count (32× ok, 11× 'ok, besser GO', 3× 'ok, manual fix', 8× 'fp, bug'), and the assertions
# are the numbers the report measured by hand: 8 of 52 judged NO-GOs = 15%.
N=$((N+1)); FLD="$TMP/fld$N.md"
SETUPWHY='✗ main declares no required status checks, so EVERY reported check must be SUCCESS — 1 of 1 are not: ci=IN_PROGRESS'
DOMWHY='✗ touches an excluded domain — the human merges these, always: EX-GUARD EX-GDPR; ✓ all 1 check(s) main requires are SUCCESS'
GOWHY='✓ all 1 check(s) main requires are SUCCESS; ✓ no excluded domain touched'
{ printf '| when (UTC) | PR | verdict | why | outcome |\n|---|---|---|---|---|\n'
  printf '| 2026-07-22T09:00Z | 100 | NO-GO | %s | ok |\n' "$SETUPWHY"
  i=0; while [ "$i" -lt 22 ]; do i=$((i+1))
    printf '| 2026-07-23T09:%02dZ | %d | NO-GO | %s | ok |\n' "$i" $((100+i)) "$SETUPWHY"; done
  i=0; while [ "$i" -lt 7 ]; do i=$((i+1))
    printf '| 2026-07-25T09:%02dZ | %d | NO-GO | %s | ok |\n' "$i" $((130+i)) "$DOMWHY"; done
  i=0; while [ "$i" -lt 11 ]; do i=$((i+1))
    printf '| 2026-07-27T09:%02dZ | %d | NO-GO | %s | ok, besser GO |\n' "$i" $((140+i)) "$SETUPWHY"; done
  i=0; while [ "$i" -lt 3 ]; do i=$((i+1))
    printf '| 2026-07-29T09:%02dZ | %d | NO-GO | %s | ok, manual fix |\n' "$i" $((160+i)) "$SETUPWHY"; done
  i=0; while [ "$i" -lt 8 ]; do i=$((i+1))
    printf '| 2026-08-01T09:%02dZ | %d | NO-GO | %s | fp, bug |\n' "$i" $((170+i)) "$SETUPWHY"; done
  i=0; while [ "$i" -lt 3 ]; do i=$((i+1))
    printf '| 2026-08-03T09:%02dZ | %d | NO-GO | %s | fn |\n' "$i" $((180+i)) "$SETUPWHY"; done
  printf '| 2026-08-05T09:00Z | 190 | NO-GO | ✗ required check(s) not green: test=IN_PROGRESS | |\n'
  printf '| 2026-08-06T09:00Z | 191 | GO | %s | ok |\n' "$GOWHY"
  printf '| 2026-08-07T09:00Z | 192 | GO | %s | |\n' "$GOWHY"
  printf '| 2026-08-08T09:00Z | 193 | MOOT | PR already merged before the gate ran | ok |\n'
  printf '| 2026-08-12T09:00Z | 194 | MOOT | PR already merged before the gate ran | |\n'
} > "$FLD"
out="$(sh "$STATS" "$FLD" 2>&1)"; rc=$?
assert "gate-stats: tags match on their first two characters — the 0% is 15%" 0 "$rc" "$out" '8 of 52 judged NO-GOs = 15%'
assert "gate-stats: 'ok, besser GO' is a calibration dial, printed as its own line" 0 "$rc" "$out" \
  "calibration: 11 of 44 correct NO-GOs were marked 'better GO' by the human"
assert "gate-stats: fn tags on NO-GO rows never reach the headline false-negative number" 0 "$rc" "$out" 'FALSE NEGATIVES[^0-9]*0'
assert "gate-stats: the misfiled fn tags get their own data-quality line" 0 "$rc" "$out" \
  '3 fn tag\(s\) on NO-GO rows — fn is defined on GO rows only'
assert "gate-stats: NO-GO causes split mechanically into setup/checks/domain/other" 0 "$rc" "$out" \
  'setup 48 · checks 1 · domain 7 · other 0'
assert "gate-stats: MOOT is a printed verdict total, and NO-GO never counts toward GO" 0 "$rc" "$out" \
  'GO 2 · NO-GO 56 · UNKNOWN 0 · MOOT 2' 'GO 58'

# A tag the parser cannot place is COUNTED AND PRINTED — a statistic that drops rows must say so —
# and `nil` (the verdict says nothing about the code) stays out of the fp/fn math entirely.
N=$((N+1)); NILF="$TMP/nil$N.md"
{ printf '| when (UTC) | PR | verdict | why | outcome |\n|---|---|---|---|---|\n'
  printf '| 2026-08-01T00:00Z | 1 | NO-GO | x | ok |\n'
  printf '| 2026-08-01T01:00Z | 2 | NO-GO | x | fp |\n'
  printf '| 2026-08-01T02:00Z | 3 | NO-GO | ✗ required check(s) not green: ci=IN_PROGRESS | nil |\n'
  printf '| 2026-08-01T03:00Z | 4 | NO-GO | x | need inspection |\n'
  printf '| 2026-08-01T04:00Z | 5 | GO | x | ok |\n'
} > "$NILF"
out="$(sh "$STATS" "$NILF" 2>&1)"; rc=$?
assert "gate-stats: nil and unmatched rows are excluded from the judged denominator" 0 "$rc" "$out" '1 of 2 judged NO-GOs = 50%'
assert "gate-stats: a nil tag is reported as its own count" 0 "$rc" "$out" '1 nil-tagged row'
assert "gate-stats: an unmatched tag is counted AND named, never silently dropped" 0 "$rc" "$out" \
  '1 unmatched tag\(s\): need inspection'

# --report: the paste-ready extract docs/open-questions.md asks field users for. It must reproduce
# the fixture's counts exactly, carry raw counts beside every rate, and never exit 0 with nothing.
rep="$(sh "$STATS" --report "$FLD" 2>&1)"; rc=$?
assert "--report reproduces the fp rate with raw counts beside it" 0 "$rc" "$rep" \
  'false positives: 8 of 52 judged NO-GOs = 15% \(ok 44 · fp 8\)'
assert "--report: verdict totals GO/NO-GO/UNKNOWN/MOOT, substring-proof" 0 "$rc" "$rep" \
  'verdicts: 60 — GO 2 · NO-GO 56 · UNKNOWN 0 · MOOT 2' 'GO 58'
assert "--report: outcome coverage tagged vs untagged" 0 "$rc" "$rep" '57 of 60 tagged \(95%\) · 3 untagged'
assert "--report: period covered is first to last row date" 0 "$rc" "$rep" '2026-07-22 → 2026-08-12'
assert "--report: top exclusion reasons, counted position-independently" 0 "$rc" "$rep" \
  'top exclusion reasons: EX-GDPR 7 · EX-GUARD 7'
out="$(sh "$STATS" --report "$TMP/absent-ledger.md" 2>&1)"; rc=$?
assert "--report with no ledger → exit 2, never 0 with empty output" 2 "$rc" "$out" 'no ledger'

# --report --mark appends the marker doctor.sh counts from — ONE line, an append, never an edit,
# and never itself a verdict row.
out="$(sh "$STATS" --report --mark "$FLD" 2>&1)"; rc=$?
assert "--report --mark still prints the report" 0 "$rc" "$out" '## Gate report'
nmark="$(grep -c '^<!-- report ' "$FLD" || true)"
if [ "$nmark" = 1 ] && grep -q 'rows=60' "$FLD"; then ok "--mark appends exactly one marker line, carrying the row count"
else bad "--mark appends exactly one marker line, carrying the row count" "markers=$nmark, rows grep: $(grep '^<!-- report ' "$FLD" | tr '\n' ' ')"; fi
out="$(sh "$STATS" "$FLD" 2>&1)"; rc=$?
assert "a marker line is never counted as a verdict row" 0 "$rc" "$out" '60 verdict\(s\)'
out="$(sh "$STATS" --mark "$FLD" 2>&1)"; rc=$?
assert "--mark without --report is refused — a marker for a report that never happened" 2 "$rc" "$out" 'only makes sense'

# ── catalog-lint.sh ─────────────────────────────────────────────────────────────────────────────
lfix() {
  N=$((N+1)); D="$TMP/l$N"
  mkdir -p "$D/docs/architecture" "$D/.claude/skills/wai-init/references" \
           "$D/.claude/skills/wai-pr-review"
  cat > "$D/.claude/skills/wai-init/references/quality-attributes.baseline.md" <<'EOF'
# Baseline

- **SEC-1 · Auth** — a. *Red Flag:* b.
- **SEC-8 · Object-Level Authorization (IDOR)** — a. *Red Flag:* b.
- **PAY-3 · Idempotent Crediting** — a. *Red Flag:* b.
- **MAINT-1 · Modularity** — a. *Red Flag:* b.

## Retired IDs

Never reuse these numbers. `MAINT-6` → `MAINT-1` · `API-3` → `MAINT-5`.
EOF
  printf 'Anchor an IDOR finding to `SEC-8`.\n' > "$D/.claude/skills/wai-pr-review/SKILL.md"
  cp "$D/.claude/skills/wai-init/references/quality-attributes.baseline.md" \
     "$D/docs/architecture/quality-attributes.md"
}
lint() { ( cd "$D" && sh "$LINT" 2>&1 ); }

echo
echo "catalog-lint.sh"

lfix; out="$(lint)"; rc=$?
assert "a consistent catalog → OK" 0 "$rc" "$out" 'VERDICT: OK'

# THE BUG THAT SHIPPED: a tailored catalog is a SUBSET, and the skills cite the BASELINE.
# Resolving skill citations against the repo's catalog fails by construction in every consuming repo.
lfix; grep -v 'SEC-8' "$D/docs/architecture/quality-attributes.md" > "$D/c" && mv "$D/c" "$D/docs/architecture/quality-attributes.md"
out="$(lint)"; rc=$?
assert "a skill citing a baseline ID the repo tailored away → still OK" 0 "$rc" "$out" 'VERDICT: OK'

# A SKILL citing a RETIRED baseline ID — the `MAINT-6` bug, in two of the suite's own artifacts.
lfix; printf 'The stub-gate incident (`MAINT-6`).\n' > "$D/.claude/skills/wai-pr-review/SKILL.md"
out="$(lint)"; rc=$?
assert "a skill citing a RETIRED baseline ID → FAIL, and says where it moved" 1 "$rc" "$out" 'RETIRED baseline ID.*MAINT-6|moved this number to: MAINT-1'

# THE FALSE POSITIVE THAT BLOCKED A PR: a backtick is the citation, and nothing else is.
lfix; printf 'Alert `API-5xx-Rate` fired. There is no AI-503 to retry.\n' > "$D/docs/notes.md"
out="$(lint)"; rc=$?
assert "an alert name and prose are not citations" 0 "$rc" "$out" 'VERDICT: OK' 'API-5|AI-503'

lfix; sed 's/\(PAY-3 · Idempotent Crediting\*\* — a\.\) \*Red Flag:\* b\./\1/' \
        "$D/docs/architecture/quality-attributes.md" > "$D/c" && mv "$D/c" "$D/docs/architecture/quality-attributes.md"
out="$(lint)"; rc=$?
assert "a missing Red Flag the baseline HAS → recoverable, no authoring" 1 "$rc" "$out" 'predates it|reconcile'

lfix; printf '\n- **SEC-1 · Auth again** — a. *Red Flag:* b.\n' >> "$D/docs/architecture/quality-attributes.md"
out="$(lint)"; rc=$?
assert "a duplicate ID → FAIL" 1 "$rc" "$out" 'duplicate'

lfix; printf 'The plan anchors this to `PAY-9`.\n' > "$D/docs/plan.md"
out="$(lint)"; rc=$?
assert "a doc citing an ID that exists nowhere → FAIL" 1 "$rc" "$out" 'PAY-9'

lfix; mkdir -p "$D/.claude/skills/wai-cicd/references/templates"
printf '# fail on a committed secret (SEC-3)\n' > "$D/.claude/skills/wai-cicd/references/templates/ci.yml"
out="$(lint)"; rc=$?
assert "a COPIED template citing a bare ID → FAIL (it rebinds on copy)" 1 "$rc" "$out" 'COPIED template'

lfix; printf -- '- **MAINT-10 · Naming** — a. *Red Flag:* b.\n' >> "$D/docs/architecture/quality-attributes.md"
out="$(lint)"; rc=$?
assert "a local ID inside the baseline's number space → FAIL" 1 "$rc" "$out" 'MAINT-10'

lfix; printf -- '- **MAINT-100 · Naming** — a. *Red Flag:* b.\n' >> "$D/docs/architecture/quality-attributes.md"
out="$(lint)"; rc=$?
assert "a local ID at >= 100 → OK" 0 "$rc" "$out" 'VERDICT: OK'

lfix; python3 - "$D/docs/architecture/quality-attributes.md" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = s.replace("\n## Retired IDs",
              "- **MAINT-10 · Naming** — a. *Red Flag:* b.\n\n## Local IDs\n\n`MAINT-10` — minted before the rule; permanent.\n\n## Retired IDs", 1)
p.write_text(s)
PY
out="$(lint)"; rc=$?
assert "a sub-100 local declared under '## Local IDs' → OK" 0 "$rc" "$out" 'VERDICT: OK'

lfix; mkdir -p "$D/docs/learnings/field-reports"
printf 'Their catalog holds `PAY-9`; ours does not.\n' > "$D/docs/learnings/field-reports/2026-01-01-x.md"
out="$(lint)"; rc=$?
assert "a verbatim field report is a FOREIGN ID space and is not linted" 0 "$rc" "$out" 'VERDICT: OK'

# ── dep-cve-scan.sh ─────────────────────────────────────────────────────────────────────────────
# The whole point: a scanner that did NOT run must read as `not_measured`, NEVER as 0 / clean. And a
# non-zero exit (which every CVE scanner returns WHEN IT FINDS vulns) is not "did not run".
CVE="$ROOT/.claude/skills/wai-security-audit/scripts/dep-cve-scan.sh"
BASEP="/usr/bin:/bin"                         # a scanner-free PATH: coreutils only, no npm/osv/cargo…
cverun() { PATH="$1" sh "$CVE" "$2" 2>&1; }   # $1 = PATH, $2 = repo dir
cvedir() { N=$((N+1)); CVD="$TMP/cve$N"; mkdir -p "$CVD"; [ -n "${1:-}" ] && printf '%s' "${2:-x}" > "$CVD/$1"; }

cvedir ""                                     # no manifests at all
out="$(cverun "$BASEP" "$CVD")"; rc=$?
assert "no ecosystem detected → nothing to scan, exit 0" 0 "$rc" "$out" 'no dependency ecosystems'
# The run-log self-log site (issue #11): the CVE sweep marks a wai-security-audit run, 1:1 mapping,
# so the SCRIPT writes the attendance row — into the SCANNED tree, which here is the fixture.
# Found-nothing is exactly the run that vanishes today; it must still leave a row.
if grep -qF '| wai-security-audit | dep CVE scan | no ecosystems detected |' "$CVD/docs/architecture/run-log.md" 2>/dev/null; then
  ok "dep-cve-scan self-logs its run into the scanned tree (skill=wai-security-audit)"
else bad "dep-cve-scan self-logs its run into the scanned tree" "no row in $CVD/docs/architecture/run-log.md"; fi

# Package.swift with no osv-scanner on PATH: the script has no native swift scanner, so this is the
# clean fail-loud case, deterministic on any runner (osv is never preinstalled).
cvedir Package.swift 'name'
out="$(cverun "$BASEP" "$CVD")"; rc=$?
assert "a manifest with no scanner → not_measured, exit 2 (never a silent 0)" 2 "$rc" "$out" 'ecosystem=swift.*not_measured' 'ran=true'
if grep -qF '| wai-security-audit | dep CVE scan | gap: at least one ecosystem not measured |' "$CVD/docs/architecture/run-log.md" 2>/dev/null; then
  ok "a gapped scan's run-log row names the gap state, never a silent zero"
else bad "a gapped scan's run-log row names the gap state" "no gap row in $CVD/docs/architecture/run-log.md"; fi

# A stub npm that FINDS vulns: valid JSON AND a non-zero exit — the exact shape real `npm audit` has.
# The script must call this MEASURED (it keys on the JSON, not the exit code) and parse the counts.
CVESTUB="$TMP/cvestub"; mkdir -p "$CVESTUB"
cat > "$CVESTUB/npm" <<'NPM'
#!/bin/sh
[ "$1" = audit ] && { printf '{"metadata":{"vulnerabilities":{"critical":1,"high":2,"moderate":3,"total":6}}}'; exit 1; }
exit 0
NPM
chmod +x "$CVESTUB/npm"
cvedir package.json '{}'
out="$(cverun "$CVESTUB:$BASEP" "$CVD")"; rc=$?
assert "npm audit found vulns (non-zero exit, valid JSON) → MEASURED, counts parsed, exit 0" 0 "$rc" "$out" 'ecosystem=npm .*ran=true.*crit=1 high=2 med=3'
# Even a fully-measured lockfile scan must STATE it covers lockfile deps only — OS + runtime-bundled
# CVEs (undici) are invisible here. A clean lockfile result that implies a clean runtime is the exact
# green-check-that-lies this suite exists to prevent.
assert "a measured scan still states its scope (lockfile only, not the image)" 0 "$rc" "$out" 'SCOPE: lockfile'

# A stub npm that PRINTED NOTHING — the trap. Must be not_measured, not a clean 0.
mkdir -p "$TMP/cvestub-empty"
printf '#!/bin/sh\nexit 0\n' > "$TMP/cvestub-empty/npm"; chmod +x "$TMP/cvestub-empty/npm"
cvedir package.json '{}'
out="$(cverun "$TMP/cvestub-empty:$BASEP" "$CVD")"; rc=$?
assert "npm present but printed nothing → not_measured, exit 2 (the printed-nothing guard)" 2 "$rc" "$out" 'ecosystem=npm.*not_measured'

# ── doctor.sh (repo drift / presence) ───────────────────────────────────────────────────────────
# The whole point: a contract that silently went off (merge-gate.conf missing → gate returns
# UNKNOWN on every PR) must be REPORTED, not left looking like a repo nobody touched.
DOCTOR="$ROOT/.claude/skills/wai/scripts/doctor.sh"
docdir() { N=$((N+1)); DD="$TMP/doc$N"; mkdir -p "$DD/docs/architecture"; }

# DRIFT IS EXIT 1, NOT 2 — doctor shipped with the very fold it exists to report. Drift is a FACT
# ABOUT THE REPO (the suite's code for a defined negative is 1); 2 is reserved for "could not
# check", and doctor used to return it for both. merge-gate.sh's header calls that distinction
# load-bearing; a drift detector that erases it is the same bug one level up.
docdir; printf '# cat\n' > "$DD/docs/architecture/quality-attributes.md"
out="$(sh "$DOCTOR" "$DD" 2>&1)"; rc=$?
assert "catalog but no merge-gate.conf → DRIFT, exit 1 (a fact about the repo, not an UNKNOWN)" 1 "$rc" "$out" 'merge-gate.conf is MISSING'

# The same repo WITH a conf that actually names its contract paths → no drift. An EMPTY
# CONTRACT_PATHS is itself drift now: the classifier skips the whole contract test when the key is
# empty, so billing and auth PRs classify CLEAN while the gate prints that it checked them.
printf 'CONTRACT_PATHS="src/billing/*"\n' > "$DD/docs/architecture/merge-gate.conf"
out="$(sh "$DOCTOR" "$DD" 2>&1)"; rc=$?
assert "catalog + a POPULATED merge-gate.conf → no drift, exit 0" 0 "$rc" "$out" 'merge gate is configured' 'DRIFT'

# And the empty-glob case explicitly, because a conf that exists is not a conf that checks anything.
printf 'CONTRACT_PATHS=""\n' > "$DD/docs/architecture/merge-gate.conf"
out="$(sh "$DOCTOR" "$DD" 2>&1)"; rc=$?
assert "an EMPTY CONTRACT_PATHS is drift — the gate would pass billing PRs" 1 "$rc" "$out" 'CONTRACT_PATHS'

# A repo not set up at all (no catalog) → not drift; nothing can drift before setup.
docdir; out="$(sh "$DOCTOR" "$DD" 2>&1)"; rc=$?
assert "no catalog → advisory only, exit 0 (nothing to drift from yet)" 0 "$rc" "$out" 'no quality catalog' 'DRIFT'

# A legacy learning ledger is an ADVISORY (legitimate in CI), never drift on its own.
docdir; printf '# cat\n' > "$DD/docs/architecture/quality-attributes.md"
printf 'CONTRACT_PATHS="src/billing/*"\n' > "$DD/docs/architecture/merge-gate.conf"
mkdir -p "$DD/temp/learning"; printf 'x\n' > "$DD/temp/learning/ledger.md"
out="$(sh "$DOCTOR" "$DD" 2>&1)"; rc=$?
assert "a legacy learning ledger is an advisory, not drift (exit 0)" 0 "$rc" "$out" 'temp/learning/' 'DRIFT'

# The UNKNOWN branch must exist and be reachable, or the newly separated state is an untested
# branch — the exact failure this file's header is about.
docdir; printf '# cat\n' > "$DD/docs/architecture/quality-attributes.md"
printf 'CONTRACT_PATHS="src/*"\n' > "$DD/docs/architecture/merge-gate.conf"
chmod 000 "$DD/docs/architecture/merge-gate.conf" 2>/dev/null
out="$(sh "$DOCTOR" "$DD" 2>&1)"; rc=$?
chmod 644 "$DD/docs/architecture/merge-gate.conf" 2>/dev/null
assert "an unreadable merge-gate.conf → UNKNOWN, exit 2 (could not check, not a finding)" 2 "$rc" "$out" ''

# Hooks that are committed but not wired. `.githooks/` is inert until `core.hooksPath` points at
# it — git looks in `.git/hooks` and never runs these. The README sells them as an enforcement
# layer, and the suite's own repo shipped without the wiring, so the layer was advertised and
# absent at the same time. Nothing checked, so nothing noticed; that is the whole pattern again.
docdir; git -C "$DD" init -q 2>/dev/null; mkdir -p "$DD/.githooks"
printf '#!/bin/sh\nexit 0\n' > "$DD/.githooks/pre-commit"
out="$( cd "$DD" && sh "$DOCTOR" . 2>&1 )"; rc=$?
assert "committed hooks with no core.hooksPath → DRIFT, and it names the fix" 1 "$rc" "$out" 'core.hooksPath'
git -C "$DD" config core.hooksPath .githooks
out="$( cd "$DD" && sh "$DOCTOR" . 2>&1 )"; rc=$?
assert "wired hooks are not reported as drift" 0 "$rc" "$out" 'hooks are wired'
# An ABSOLUTE path to the very same directory is wired, not "elsewhere". The literal compare
# called it drift and told the operator to fix a non-problem — predicted as an edge in review,
# hit for real in this repo on 2026-08-13 (issue #18). Directories compare, strings don't.
git -C "$DD" config core.hooksPath "$DD/.githooks"
out="$( cd "$DD" && sh "$DOCTOR" . 2>&1 )"; rc=$?
assert "an absolute core.hooksPath to the SAME dir is wired, not drift (#18)" 0 "$rc" "$out" 'hooks are wired' 'points elsewhere'
# And a path that genuinely resolves elsewhere (or nowhere) stays honest drift.
git -C "$DD" config core.hooksPath /nonexistent-hooks-dir
out="$( cd "$DD" && sh "$DOCTOR" . 2>&1 )"; rc=$?
assert "a hooksPath that resolves nowhere is still drift" 1 "$rc" "$out" 'points elsewhere'

# The report cadence: ~250 field verdicts produced zero reports, because reporting happened by
# mood. doctor now counts verdicts since the last `<!-- report … -->` marker and names the
# threshold — ADVISORY in every state, because WHAT is worth reporting stays judgment (ADR-0002).
docdir; printf '# cat\n' > "$DD/docs/architecture/quality-attributes.md"
printf 'CONTRACT_PATHS="src/billing/*"\n' > "$DD/docs/architecture/merge-gate.conf"
{ printf '| when (UTC) | PR | verdict | why | outcome |\n|---|---|---|---|---|\n'
  printf '| 2026-08-01T00:00Z | 1 | GO | x | |\n'
  printf '| 2026-08-02T00:00Z | 2 | NO-GO | x | |\n'
  printf '| 2026-08-03T00:00Z | 3 | GO | x | |\n'
} > "$DD/docs/architecture/gate-ledger.md"
out="$(sh "$DOCTOR" "$DD" 2>&1)"; rc=$?
assert "doctor: a ledger with no marker → 'no report marker; N verdicts on record', exit 0" 0 "$rc" "$out" \
  'no report marker; 3 verdict\(s\) on record' 'DRIFT'
printf '<!-- report 2026-08-03 rows=3 -->\n| 2026-08-04T00:00Z | 4 | GO | x | |\n' >> "$DD/docs/architecture/gate-ledger.md"
out="$(sh "$DOCTOR" "$DD" 2>&1)"; rc=$?
assert "doctor: below threshold → verdicts-since-marker advisory, default threshold named" 0 "$rc" "$out" \
  '1 verdict\(s\) since the last report marker \(threshold 25, override REPORT_THRESHOLD env\)' 'DRIFT'
out="$(REPORT_THRESHOLD=1 sh "$DOCTOR" "$DD" 2>&1)"; rc=$?
assert "doctor: at threshold → a pointer to cut the report, still advisory (never exit-1 drift)" 0 "$rc" "$out" \
  'AT/OVER the report threshold \(1' 'DRIFT'

# install.sh — through the REAL path: install from this checkout into a temp dir, then assert it
# stamped the suite version and RAN doctor (the update-time signal that replaces the old sentence).
IDIR="$TMP/install-target"; mkdir -p "$IDIR"
out="$(sh "$ROOT/install.sh" "$IDIR" 2>&1)"; rc=$?
assert "install.sh stamps the suite version and runs doctor" 0 "$rc" "$out" 'doctor: '
if [ -f "$IDIR/.claude/.wai-suite-version" ]; then ok "install.sh writes .wai-suite-version (Phase B foundation)"
else bad "install.sh writes .wai-suite-version" "no version file at $IDIR/.claude/"; fi

# install.sh × the platform→wai rename.
#
# Every repo that already runs this suite carries a `.platform-suite-manifest`. If the installer
# does not recognise it, it owns nothing, prunes nothing, and lays eleven `wai-*` skills BESIDE the
# eleven `platform-*` ones — near-identical descriptions competing for the same trigger, in the
# repos most likely to update first. The manifest still confers ownership, and only over names this
# suite ever installed: a foreign skill listed in a hand-edited manifest must survive.
MDIR="$TMP/install-legacy"; mkdir -p "$MDIR/.claude/skills"
for legacy in platform platform-init platform-pr-review learning-gap; do
  mkdir -p "$MDIR/.claude/skills/$legacy"; echo "old" > "$MDIR/.claude/skills/$legacy/SKILL.md"
done
mkdir -p "$MDIR/.claude/skills/my-own-skill"; echo "mine" > "$MDIR/.claude/skills/my-own-skill/SKILL.md"
printf 'platform\nplatform-init\nplatform-pr-review\nlearning-gap\nmy-own-skill\n' > "$MDIR/.claude/.platform-suite-manifest"
printf 'deadbee  (ref main)\n' > "$MDIR/.claude/.platform-suite-version"
out="$(sh "$ROOT/install.sh" "$MDIR" 2>&1)"; rc=$?
assert "a legacy platform-* install is migrated, not duplicated" 0 "$rc" "$out" 'pruned .*: platform-init'
for legacy in platform platform-init platform-pr-review learning-gap; do
  if [ -d "$MDIR/.claude/skills/$legacy" ]; then
    bad "legacy '$legacy' is pruned" "still present in $MDIR/.claude/skills/"
  else ok "legacy '$legacy' is pruned"; fi
done
if [ -f "$MDIR/.claude/skills/my-own-skill/SKILL.md" ] && [ "$(cat "$MDIR/.claude/skills/my-own-skill/SKILL.md")" = "mine" ]; then
  ok "a foreign skill listed in the legacy manifest is NOT deleted (the name is not ours)"
else bad "a foreign skill listed in the legacy manifest is NOT deleted" "my-own-skill was touched"; fi
if [ -d "$MDIR/.claude/skills/wai-init" ] && [ -f "$MDIR/.claude/.wai-suite-manifest" ]; then
  ok "the wai suite is installed and its manifest written"
else bad "the wai suite is installed and its manifest written" "missing wai-init or .wai-suite-manifest"; fi
if [ ! -f "$MDIR/.claude/.platform-suite-manifest" ] && [ ! -f "$MDIR/.claude/.platform-suite-version" ]; then
  ok "the legacy manifest and version stamp are removed (migration runs once)"
else bad "the legacy manifest and version stamp are removed" "a legacy file survived"; fi

# THE FIRST-REVIEW BLOCKER, and it destroyed skills on the path the README recommends.
#
# Under `curl … | sh`, `$0` is the shell — `dirname "$0"` is ".", so HERE became the TARGET
# project. A target that already has the suite installed HAS a `.claude/skills`, so the
# checkout-detection fired on the destination: SRC == SKILLS_DIR. Step 5 then did `rm -rf` on each
# skill and `cp` from the directory it had just deleted. Every documented UPDATE run hit it — the
# first install was fine, which is exactly why nobody saw it.
#
# `cat install.sh | sh` reproduces it faithfully: same argv shape, same $0.
#
# SKILLS_REPO must stay UNSET — the checkout-detection is guarded by `[ -z "$SKILLS_REPO" ]`, so
# setting it to a local path to keep the test offline would disable the branch under test. (The
# first version of this test did that and passed against the broken installer.) The `git` stub
# intercepts the clone instead; everything else reaches the real git.
PDIR="$TMP/install-piped"; mkdir -p "$PDIR/.claude/skills/wai-init"
echo "stale" > "$PDIR/.claude/skills/wai-init/SKILL.md"
printf 'wai\nwai-init\n' > "$PDIR/.claude/.wai-suite-manifest"
out="$( cd "$PDIR" && PATH="$STUB:$PATH" GIT_STUB_SRC="$ROOT" \
        sh -c 'cat "$1"/install.sh | sh' _ "$ROOT" 2>&1 )"; rc=$?
assert "a PIPED update clones instead of taking the destination for the source" \
  0 "$rc" "$out" 'source: https' 'source: this checkout'
if [ -s "$PDIR/.claude/skills/wai-init/SKILL.md" ] && [ -d "$PDIR/.claude/skills/wai-pr-review" ]; then
  ok "a piped update leaves a full, non-empty suite behind"
else bad "a piped update leaves a full, non-empty suite behind" "wai-init/SKILL.md empty or wai-pr-review missing"; fi

# The rip cord: whatever the mode, source == destination must never reach the replace loop.
RDIR="$TMP/install-self"; mkdir -p "$RDIR"
cp -R "$ROOT/.claude" "$RDIR/.claude"
cp "$ROOT/install.sh" "$RDIR/install.sh"
out="$(sh "$RDIR/install.sh" "$RDIR" 2>&1)"; rc=$?
assert "source == destination is refused, not executed" 1 "$rc" "$out" 'same directory'
if [ -s "$RDIR/.claude/skills/wai-init/SKILL.md" ]; then ok "the refused run destroyed nothing"
else bad "the refused run destroyed nothing" "wai-init/SKILL.md is gone or empty"; fi

# THE LEDGER SURVIVES AN UPDATE. A field repo lost every gate verdict before 2026-07-22 to a
# suite update (issue #10) — the ledger is append-only experience that cannot be reconstructed,
# so an installer that can delete it is a data-loss risk, not a file manager. install.sh states
# the guarantee next to its prune logic; THIS CASE IS THE GUARD: it goes red the day anyone
# teaches install.sh to "clean up" docs/. The fixture is an UPDATE, not a first install — a
# `.wai-suite-manifest` is present and a stale suite skill sits in place — because only the
# update path runs the prune/replace loops next to which the user's data lives (the piped-update
# bug above was invisible for the same reason: first installs were always fine). Two asserts
# below prove the update path actually ran: the manifest suppressed the first-run collision
# warning, and the stale skill was replaced.
UDIR="$TMP/install-update-ledger"; mkdir -p "$UDIR/.claude/skills/wai-init" "$UDIR/docs/architecture"
echo "stale" > "$UDIR/.claude/skills/wai-init/SKILL.md"
printf 'wai\nwai-init\n' > "$UDIR/.claude/.wai-suite-manifest"
{ printf '| when (UTC) | PR | verdict | why | outcome |\n|---|---|---|---|---|\n'
  printf '| 2026-07-22T00:00Z | 1 | NO-GO | no required checks | ok |\n'
  printf '| 2026-08-01T00:00Z | 2 | GO | all green | ok |\n'
  printf '| 2026-08-12T00:00Z | 3 | NO-GO | test=IN_PROGRESS | fp, bug |\n'
} > "$UDIR/docs/architecture/gate-ledger.md"
printf '| 2026-08-12T09:00Z | wai-security-audit | repo | no findings |\n' > "$UDIR/docs/architecture/run-log.md"
cp "$UDIR/docs/architecture/gate-ledger.md" "$TMP/ledger.before"
cp "$UDIR/docs/architecture/run-log.md"     "$TMP/runlog.before"
out="$(sh "$ROOT/install.sh" "$UDIR" 2>&1)"; rc=$?
assert "an update into a repo with a populated ledger runs as an UPDATE (manifest honoured, no first-run collision warning)" \
  0 "$rc" "$out" 'installed: wai-init' 'will be overwritten'
if [ -s "$UDIR/.claude/skills/wai-init/SKILL.md" ] && [ "$(cat "$UDIR/.claude/skills/wai-init/SKILL.md")" != "stale" ]; then
  ok "the update path was exercised: the stale suite skill was replaced"
else bad "the update path was exercised: the stale suite skill was replaced" "wai-init/SKILL.md still 'stale' — this fixture no longer tests an update"; fi
if cmp -s "$TMP/ledger.before" "$UDIR/docs/architecture/gate-ledger.md"; then
  ok "the gate ledger (3 rows) is byte-identical after the update"
else bad "the gate ledger (3 rows) is byte-identical after the update" "install.sh modified docs/architecture/gate-ledger.md"; fi
if cmp -s "$TMP/runlog.before" "$UDIR/docs/architecture/run-log.md"; then
  ok "the run log is byte-identical after the update"
else bad "the run log is byte-identical after the update" "install.sh modified docs/architecture/run-log.md"; fi
if [ "$(ls "$UDIR/docs/architecture" | wc -l | tr -d ' ')" = "2" ]; then
  ok "the installer wrote nothing into docs/ (still exactly the two user files)"
else bad "the installer wrote nothing into docs/" "docs/architecture now holds: $(ls "$UDIR/docs/architecture" | tr '\n' ' ')"; fi

# ── excluded-domains.sh ─────────────────────────────────────────────────────────────────────────
# The ONE "is this an excluded domain?" classifier. merge-gate.sh §5-6 and the autonomy drain both
# delegate here — two copies of the most load-bearing safety question in the suite would be two
# copies to forget to widen. Paths + diff are authoritative; a missing label can never suppress a
# real match; an input that cannot be read is HELD, never CLEAR. The conf locations are overridden
# with EXCLUDED_DOMAINS_MERGE_CONF / _COORD_CONF so every case runs against a captured file-list +
# diff, no gh and no cwd games — identical under bash 3.2 and dash.
ED="$ROOT/.claude/skills/wai/scripts/excluded-domains.sh"

edfix() {   # a fresh fixture: a configured, autonomy-armed, otherwise-CLEAN surface
  N=$((N+1)); ED_D="$TMP/ed$N"; mkdir -p "$ED_D"
  printf 'CONTRACT_PATHS="apps/api/src/billing/* src/billing/* apps/api/src/auth/*"\nMIGRATION_PATHS="migrations/*"\nERASURE_PATHS="apps/api/src/erasure/*"\n' > "$ED_D/merge-gate.conf"
  printf 'AUTONOMY_ENABLED="yes"\nAUTONOMY_SAFE_PATHS="docs/* src/util/*"\nAUTONOMY_AFFIRMED="2026-08-01"\nCOMMS_TOOL="none"\n' > "$ED_D/coordination.conf"
  printf 'src/util/format.ts\n' > "$ED_D/files"     # clean by default: not guard/contract/mig/erasure
  printf '+  return a + b\n'     > "$ED_D/diff"
}
edrun() {   # classify the fixture's captured file-list + diff; $@ = extra flags (e.g. --autonomy)
  EXCLUDED_DOMAINS_MERGE_CONF="$ED_D/merge-gate.conf" \
  EXCLUDED_DOMAINS_COORD_CONF="$ED_D/coordination.conf" \
  sh "$ED" --files "$ED_D/files" --diff "$ED_D/diff" "$@" 2>&1
}

echo
echo "excluded-domains.sh"

# THE PASS PATH FIRST, on purpose. A classifier that never says CLEAR forces every change to a human
# and gets routed around — the same untested-pass-branch failure the merge gate shipped for months.
edfix; out="$(edrun)"; rc=$?
assert "a clean refactor → CLEAR, exit 0" 0 "$rc" "$out" 'VERDICT: CLEAR' 'EXCLUDED'

# An EMPTY --repo value is refused as a usage error, never silently defaulted. merge-gate.sh
# shipped the silent version (a valueless --repo fell back to the local remote — the exact failure
# the flag exists to prevent); this parser carried the same hole for `--repo ""` and `--repo=`,
# and the two parsers must not fork apart again.
edfix; out="$(edrun --repo '')"; rc=$?
assert "--repo with an empty value → usage error, exit 2" 2 "$rc" "$out" 'repo needs OWNER/NAME'
edfix; out="$(edrun --repo=)"; rc=$?
assert "--repo= (empty inline form) → usage error, exit 2" 2 "$rc" "$out" 'repo needs OWNER/NAME'

# A billing path is contract-domain → EX-PAY, from the PATH alone.
edfix; printf 'src/billing/tokens.ts\n' > "$ED_D/files"
out="$(edrun)"; rc=$?
assert "a billing path → EX-PAY, exit 1" 1 "$rc" "$out" 'EXCLUDED-DOMAINS:.*EX-PAY'

# THE HOLE THE OLD GATE LEFT OPEN — and the EX-GDPR regression (was CLEAR/GO, now EXCLUDED). A
# `DELETE FROM users` in an ordinary code file, OUTSIDE any migration/erasure path, was never caught:
# the old §6 only grepped INSIDE MIGRATION_PATHS, so a path-only check said clean → GO. The whole-diff
# erasure grep now trips EX-GDPR. It is NOT EX-MIG — no migration file is touched, so the AND-gated
# migration check cannot be what caught it. (The merge-gate.sh INTEGRATION of this — §5-6 delegating
# here — is blueprint I1 and lands with that script; this pins the classifier the gate delegates to.)
edfix; printf 'src/services/reports.ts\n' > "$ED_D/files"
printf '+  await db.query("DELETE FROM users WHERE id = $1");\n' > "$ED_D/diff"
out="$(edrun)"; rc=$?
assert "DELETE FROM users outside any migration/erasure path → EX-GDPR (the closed self-merge hole)" 1 "$rc" "$out" 'EXCLUDED-DOMAINS:.*EX-GDPR' 'EX-MIG'

# Editing merge-gate.conf to drop billing from CONTRACT_PATHS is the two-step escalation the floor
# exists to stop (drop the path in one harmless-looking PR, then merge billing freely). The gate's own
# config is a guardrail → EX-GUARD, no matter what the config it points at currently says.
edfix; printf 'docs/architecture/merge-gate.conf\n' > "$ED_D/files"
printf -- '-CONTRACT_PATHS="apps/api/src/billing/*"\n+CONTRACT_PATHS=""\n' > "$ED_D/diff"
out="$(edrun)"; rc=$?
assert "a diff dropping billing from CONTRACT_PATHS → EX-GUARD (the gate config is a guardrail)" 1 "$rc" "$out" 'EXCLUDED-DOMAINS:.*EX-GUARD'

# LABEL-SUPPRESSION REGRESSION. Advisory signals — labels, cited-ID family prefixes — may only WIDEN.
# A real path match is authoritative: here a billing path with NO label at all (--files mode has no
# label channel) and diff text naming an unrelated 'refactor' still trips EX-PAY. A missing or renamed
# label can never make a path/diff match go away.
edfix; printf 'src/billing/charge.ts\n' > "$ED_D/files"
printf '+// refactor: rename an internal helper, no behaviour change\n' > "$ED_D/diff"
out="$(edrun)"; rc=$?
assert "a missing/renamed label cannot SUPPRESS a path match (advisory widens only)" 1 "$rc" "$out" 'EXCLUDED-DOMAINS:.*EX-PAY'

# An input that cannot be read is HELD, never CLEAR — the fail-closed rule the whole suite rests on.
edfix; out="$(EXCLUDED_DOMAINS_MERGE_CONF="$ED_D/merge-gate.conf" EXCLUDED_DOMAINS_COORD_CONF="$ED_D/coordination.conf" sh "$ED" --files "$ED_D/files" --diff "$ED_D/does-not-exist" 2>&1)"; rc=$?
assert "an unreadable diff → UNKNOWN, exit 2 (fail-closed, never CLEAR)" 2 "$rc" "$out" 'UNKNOWN' 'VERDICT: CLEAR'

# ── excluded-domains.sh --autonomy (the ALLOWLIST eligibility gate) ──────────────────────────────
# The blocklist above is UNDER-inclusive by construction — it cannot know a risky path idiom no rule
# was written for. Trusting "blocklist CLEAR" to authorise an unattended merge fails OPEN on exactly
# the paths nobody named. So autonomy inverts the polarity: eligible ONLY if every touched path is in
# the human-affirmed AUTONOMY_SAFE_PATHS AND the blocklist is clear AND the exclusion surface is
# actually configured AND a human affirmed it. Anything else is HELD.
echo
echo "excluded-domains.sh --autonomy"

# THE PASS PATH. Without a case that says ELIGIBLE, the whole allowlist is an untested branch failing
# closed. src/util/format.ts is inside AUTONOMY_SAFE_PATHS, blocklist clear, surface configured+affirmed.
edfix; out="$(edrun --autonomy)"; rc=$?
assert "safe-path-only clean diff, surface configured + affirmed → AUTONOMY-ELIGIBLE, exit 0" 0 "$rc" "$out" 'AUTONOMY-ELIGIBLE'

# THE FAIL-OPEN THE ALLOWLIST INVERTS. The blocklist is CLEAR here, yet the path is outside
# AUTONOMY_SAFE_PATHS → HELD. Proving it is the ALLOWLIST holding it (not the blocklist): the output
# must NOT say the blocklist is unclear.
edfix; printf 'src/services/reports.ts\n' > "$ED_D/files"
out="$(edrun --autonomy)"; rc=$?
assert "a path NOT in AUTONOMY_SAFE_PATHS → HELD even though the blocklist is CLEAR, exit 1" 1 "$rc" "$out" 'not provably safe|not in the affirmed AUTONOMY_SAFE_PATHS' 'blocklist is not clear'

# An unconfigured or unaffirmed surface REFUSES autonomy outright. Empty CONTRACT_PATHS under
# --autonomy means "every path is contract-domain", never "no path touched".
edfix; printf 'CONTRACT_PATHS=""\nMIGRATION_PATHS="migrations/*"\nERASURE_PATHS="apps/api/src/erasure/*"\n' > "$ED_D/merge-gate.conf"
out="$(edrun --autonomy)"; rc=$?
assert "empty CONTRACT_PATHS under --autonomy → not eligible (every path is contract-domain), exit 2" 2 "$rc" "$out" 'CONTRACT_PATHS is empty' 'AUTONOMY-ELIGIBLE'

edfix; printf 'CONTRACT_PATHS="apps/api/src/billing/*"\nMIGRATION_PATHS="migrations/*"\nERASURE_PATHS=""\n' > "$ED_D/merge-gate.conf"
out="$(edrun --autonomy)"; rc=$?
assert "empty ERASURE_PATHS under --autonomy → not eligible (erasure surface unconfigured), exit 2" 2 "$rc" "$out" 'ERASURE_PATHS is empty' 'AUTONOMY-ELIGIBLE'

edfix; printf 'AUTONOMY_ENABLED="yes"\nAUTONOMY_SAFE_PATHS="docs/* src/util/*"\nAUTONOMY_AFFIRMED=""\nCOMMS_TOOL="none"\n' > "$ED_D/coordination.conf"
out="$(edrun --autonomy)"; rc=$?
assert "missing AUTONOMY_AFFIRMED under --autonomy → not eligible (no human affirmed), exit 2" 2 "$rc" "$out" 'AUTONOMY_AFFIRMED is absent' 'AUTONOMY-ELIGIBLE'

# ── merge-gate.sh × autonomy: the merge always routes through THIS gate ──────────────────────────
# There is NO autonomous-merge command. Whatever a drain-preflight decided, the real merge runs this
# gate and obeys this exit code — so an item a preflight wrongly kept is still stopped here, and the
# team-mode approval wall (§4) is independent of the domain classification and must survive any future
# extraction of §5-6 into excluded-domains.sh.
echo
echo "merge-gate.sh × autonomy"

# The "no bypass" invariant: a contract-domain change reaches the real gate on its final diff → NO-GO,
# no matter what a preflight thought. The preflight is advisory; the gate decides.
gfix; printf 'apps/api/src/billing/charge.ts\n' > "$D/files"
out="$(gate)"; rc=$?
assert "a preflight-kept contract-domain item still → NO-GO at the real gate (no autonomous bypass)" 1 "$rc" "$out" 'EX-PAY' 'VERDICT: GO'

# Team mode with NO enforced approval rule → NO-GO. `gh pr merge --auto` merges the instant nothing is
# outstanding, and with no required review that instant is NOW — the "a second human approved it"
# guarantee silently evaporates. §4 owns this; it is NOT the domain classifier's remit, and it must
# still bite after §5-6 are extracted. (No ruleset-raw / protection fixture ⇒ no approval rule found.)
gfix; printf '# Q\n\n**Repo mode:** team\n\n- **SEC-1 · Auth** — a. *Red Flag:* b.\n' > "$D/docs/architecture/quality-attributes.md"
out="$(gate)"; rc=$?
assert "team mode with no enforced approval → NO-GO (the §4 approval wall stands alone)" 1 "$rc" "$out" 'no enforced approval' 'VERDICT: GO'

# ── single source: coordination-lint's floor == excluded-domains.sh --list-domains --policy-only ──
# The six policy domains a human may enumerate for the autonomy floor are NOT typed twice. The list
# lives in excluded-domains.sh; coordination-lint.sh SOURCES it live (it does not keep a copy). These
# cases pin both halves and make the binding load-bearing: the authority prints exactly the six
# (EX-GUARD is the un-listable hardcoded floor, excluded), and a conf that NARROWS that set below what
# the authority prints is caught — so the two can never drift into two independently-typed copies.
COORDLINT="$ROOT/.claude/skills/wai-init/scripts/coordination-lint.sh"

POLICY="$(sh "$ED" --list-domains --policy-only 2>&1)"; rc=$?
assert "--list-domains --policy-only prints the policy tags, never EX-GUARD" 0 "$rc" "$POLICY" 'EX-PAY' 'EX-GUARD'
NPOL="$(printf '%s\n' "$POLICY" | grep -c '^EX-' || true)"
assert "the policy floor is exactly six domains (EX-GUARD excluded)" 0 "$([ "$NPOL" = 6 ] && echo 0 || echo 1)" "policy tags: $(printf '%s' "$POLICY" | tr '\n' ' ')"
out="$(sh "$ED" --list-domains 2>&1)"; rc=$?
assert "--list-domains (full) carries EX-GUARD as the hardcoded floor" 0 "$rc" "$out" 'EX-GUARD'

# Build a coordination.conf whose AUTONOMY_EXCLUDED mirrors the authority's list EXACTLY, then a second
# one missing one tag. Because coordination-lint sources its floor from the SAME command, the first
# must pass and the second must fail naming the dropped tag — that IS the single-source binding, tested.
slfix() {   # $1 = the AUTONOMY_EXCLUDED value to write
  N=$((N+1)); SL="$TMP/sl$N"; mkdir -p "$SL"
  printf 'CONTRACT_PATHS="apps/api/src/billing/*"\nERASURE_PATHS="apps/api/src/erasure/*"\nMIGRATION_PATHS="migrations/*"\n' > "$SL/merge-gate.conf"
  { printf 'AUTONOMY_ENABLED="yes"\n'
    printf 'AUTONOMY_EXCLUDED="%s"\n' "$1"
    printf 'AUTONOMY_SAFE_PATHS="docs/*"\nAUTONOMY_AFFIRMED="2026-08-01"\nCOMMS_TOOL="none"\n'; } > "$SL/coordination.conf"
}
# Each domain as TAG:: — named, with empty id slots (ADR-0003: a bare copied catalog id rebinds).
EXCL_ALL=""
# shellcheck disable=SC2086  # POLICY is one bare EX-* tag per line — word-splitting is intended
for _t in $POLICY; do EXCL_ALL="$EXCL_ALL $_t::"; done
slfix "$EXCL_ALL"
out="$(sh "$COORDLINT" "$SL/coordination.conf" "$SL/quality-attributes.md" 2>&1)"; rc=$?
assert "a conf whose floor mirrors the authority's list exactly → OK" 0 "$rc" "$out" 'VERDICT: OK'

DROP="$(printf '%s\n' "$POLICY" | grep '^EX-' | tail -n 1)"
EXCL_NARROW=""
# shellcheck disable=SC2086  # same: intentional word-split over bare tags
for _t in $(printf '%s\n' "$POLICY" | grep '^EX-' | sed '$d'); do EXCL_NARROW="$EXCL_NARROW $_t::"; done
slfix "$EXCL_NARROW"
out="$(sh "$COORDLINT" "$SL/coordination.conf" "$SL/quality-attributes.md" 2>&1)"; rc=$?
assert "a conf that NARROWS the floor below the authority's list → FAILED, names the missing tag" 1 "$rc" "$out" "missing:.*$DROP"

# ── the repo itself ─────────────────────────────────────────────────────────────────────────────
echo
echo "the repo"

out="$( cd "$ROOT" && sh "$LINT" 2>&1 )"; rc=$?
assert "this repo's own catalog lints clean" 0 "$rc" "$out" 'VERDICT: OK'

# The prompt↔script seam. 23 contracts, and until now nothing checked that either side still
# described the other — which is how a script gained a --repo flag its caller never passed, how a
# skill kept citing a path that resolves nowhere, and how 23 exit codes stayed undocumented at the
# place they are obeyed. The audit found fifteen of those by hand; this makes them impossible to
# reintroduce quietly. It does NOT verify that a documented invocation's ARGUMENTS are accepted —
# that needs running the script — and it says so on every run.
CLINT="$ROOT/.claude/skills/wai/scripts/contract-lint.sh"
out="$( cd "$ROOT" && sh "$CLINT" 2>&1 )"; rc=$?
assert "scripts and the prompts that invoke them still describe each other" 0 "$rc" "$out" 'VERDICT: OK'

# A MARKER DETECTOR MUST NOT CONTAIN ITS OWN MARKER — and this repo is the fixture that proves it.
# open-gap-check grepped the tree for the literal, which meant the literal was in the scripts that
# HANDLE the marker: the hook installer, the test fixtures, and the detector itself. Since
# `.claude/skills/**` is committed in every repo install.sh has touched, learning mode could never
# plant a gap in any of them — exit 1, "resolve the open gap first", and nothing to resolve. It also
# blocked a human's commit in the field via the same literal in the generated hook.
# This repo vendors the suite, so a clean checkout here IS the regression test.
out="$( cd "$ROOT" && sh .claude/skills/wai-learning-gap/scripts/open-gap-check.sh 2>&1 )"; rc=$?
assert "a repo that vendors the suite has NO open gap (the detector does not match itself)" \
       0 "$rc" "$out" 'safe to plant'

# Assembled here too — a file that greps for the marker must not contain it, or it finds itself.
# This assertion failed on its own first run for exactly that reason, one level up from the bug it
# guards. That is not a curiosity: it is the proof that the literal is contagious, and the reason
# the fix had to be "never write it contiguously" rather than "exclude some paths".
_mw='LEARN'
no_lit="$( cd "$ROOT" && git grep -I -l -e "$_mw #" -- . ':!*.md' ':!*.mdx' ':!*.markdown' 2>/dev/null | tr '\n' ' ' )"
if [ -z "$no_lit" ]; then ok "no tracked non-markdown file carries the marker as a literal"
else bad "no tracked non-markdown file carries the marker as a literal" "carried by:$no_lit"; fi

# Descriptions are FOLDED BLOCK SCALARS (`description: >-`), so these checks must read the folded
# VALUE, not the raw line. Both of them silently changed meaning when the format did — the length
# check started measuring the two characters `>-` and went green on everything, and the
# angle-bracket check started failing on the `>` that is YAML syntax rather than content. A green
# check that implies coverage it does not have is worse than a red one; this is that, twice.
desc_of() { awk '
  /^description: >-$/ { inb=1; next }
  inb && /^  [^ ]/     { sub(/^  /,""); printf "%s ", $0; next }
  inb                  { exit }
' "$1"; }

bad_w=""; bad_d=""; bad_x=""
for f in "$ROOT"/.claude/skills/*/SKILL.md; do
  s=$(basename "$(dirname "$f")")
  w=$(wc -w < "$f" | tr -d ' ')
  [ "$w" -le 5000 ] || bad_w="$bad_w $s($w)"
  dv=$(desc_of "$f")
  d=$(printf '%s' "$dv" | wc -c | tr -d ' ')
  [ "$d" -le 1024 ] || bad_d="$bad_d $s($d)"
  # A description that did not fold is a description the loader will not see in full.
  [ "$d" -ge 100 ] || bad_d="$bad_d $s(UNFOLDED:$d)"
  # No angle brackets in the frontmatter VALUES: they are injected verbatim into the system prompt.
  printf '%s%s' "$(awk '/^name:/{sub(/^name: */,""); print; exit}' "$f")" "$dv" \
    | grep -q '[<>]' && bad_x="$bad_x $s"
done
assert "every SKILL.md is under 5000 words"        0 "$([ -z "$bad_w" ] && echo 0 || echo 1)" "over:$bad_w"
assert "every description is folded and under 1024 chars" 0 "$([ -z "$bad_d" ] && echo 0 || echo 1)" "bad:$bad_d"
assert "no angle brackets in any frontmatter value" 0 "$([ -z "$bad_x" ] && echo 0 || echo 1)" "found:$bad_x"

# THE BLOCKER THIS FORMAT EXISTS FOR. `wai-requirements-planning` was the ONLY skill whose
# frontmatter was valid YAML — and precisely therefore the loader applied YAML semantics and cut
# its description at the `#` in ("plan #42"), losing 61% of it including every trigger phrase and
# the whole demarcation against the other skills. The other eleven survived only because their
# unquoted `: ` made them INVALID, so the loader fell back to raw text. Being right by way of being
# broken is not a state to ship. A folded block scalar makes `#` and `:` literal, so all twelve are
# valid AND complete. This test is the guard: strict parse, and the value must round-trip.
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  out="$( cd "$ROOT" && python3 - <<'PY' 2>&1
import glob, sys, yaml
bad = []
for f in sorted(glob.glob('.claude/skills/*/SKILL.md')):
    name = f.split('/')[2]
    try:
        fm = open(f).read().split('---')[1]
        d = yaml.safe_load(fm)
    except Exception as e:
        bad.append(f'{name}: INVALID YAML ({type(e).__name__})'); continue
    desc = (d or {}).get('description') or ''
    if '#' in desc and desc.rstrip().endswith('#'):
        bad.append(f'{name}: description ends at a #')
    if not desc.rstrip().endswith(('.', '"', ')')):
        bad.append(f'{name}: description ends mid-sentence -> {desc[-40:]!r}')
print('\n'.join(bad))
PY
)"
  assert "every frontmatter is strict YAML and no description is truncated" \
    0 "$([ -z "$out" ] && echo 0 || echo 1)" "$out"
else
  skip "strict YAML frontmatter check DID NOT RUN (no python3 + pyyaml) — the guard for the description-truncation blocker is off on this machine"
fi

# Every relative markdown link must resolve. This repo shipped with TWENTY-NINE that did not — the
# whole Evidence section of the README pointed at `docs-pub/`, a directory name that only ever
# existed in the repo this one was built FROM. The section carrying the honesty claim was the
# section entirely made of dead links, and a cold reader found it on day one.
#
# It is the same shape as every other defect in this file: nothing checked, so nothing noticed.
dead_links=""
for f in $( cd "$ROOT" && git ls-files '*.md' ); do
  d=$(dirname "$ROOT/$f")
  for t in $(grep -oE '\]\([^)]+\)' "$ROOT/$f" | sed 's/^](//; s/)$//' | cut -d'#' -f1 | grep -vE '^(https?:|mailto:|$)'); do
    # `${f}` braced deliberately: an unbraced `$f->$t` swallowed the separator into the variable
    # name under /bin/sh and died with "unbound variable" instead of failing the assertion. A test
    # that crashes is not a test that passes, and it is not one that fails usefully either.
    [ -e "$d/$t" ] || dead_links="$dead_links ${f}->${t}"
  done
done
assert "every relative markdown link resolves" 0 \
  "$([ -z "$dead_links" ] && echo 0 || echo 1)" "dead:$dead_links"

# This repo is English; its private archive is German. The detector lives in its own file — see
# the header of `tests/lang-guard.sh` for why it cannot live inline here.
out="$( sh "$ROOT/tests/lang-guard.sh" 2>&1 )"; rc=$?
assert "no German in the published tree (the archive is German; this is not)" 0 "$rc" "$out" ''

# Numbers in living prose vs. their measurements (issue #7 — three review rounds, one class).
# Without --cases this must still verify everything static and say SKIP for the case count; the
# FAIL path is exercised with a deliberately wrong count against the real README, so the branch
# that actually fires on drift is not an untested branch (the contract-lint lesson).
out="$( sh "$ROOT/tests/numbers-lint.sh" 2>&1 )"; rc=$?
assert "numbers-lint: every static claim matches its measurement" 0 "$rc" "$out" 'SKIP.*case count'
out="$( sh "$ROOT/tests/numbers-lint.sh" --cases 1 2>&1 )"; rc=$?
assert "numbers-lint: a wrong case count is STALE, exit 1" 1 "$rc" "$out" 'STALE README'
out="$( sh "$ROOT/tests/numbers-lint.sh" --cases 2>&1 )"; rc=$?
assert "numbers-lint: --cases without a value is refused, exit 2" 2 "$rc" "$out" 'needs a number'

# The ledger claims in docs/open-questions.md are LIVE numbers — the whole point of that file is
# that CI re-measures them. Two fixtures prove the branch that fires: an empty ledger makes the
# row-count claim stale, and a one-NO-GO ledger makes the GO claim stale — which is also the proof
# that NO-GO is never counted as GO by substring (the bug class check 7's comment warns about).
printf '| when (UTC) | PR | verdict | why | outcome |\n|---|---|---|---|---|\n' > "$TMP/led-empty.md"
out="$( MERGE_GATE_LEDGER="$TMP/led-empty.md" sh "$ROOT/tests/numbers-lint.sh" 2>&1 )"; rc=$?
assert "numbers-lint: a ledger claim the ledger no longer backs is STALE, exit 1" 1 "$rc" "$out" 'STALE.*gate verdicts on record'
printf '| when (UTC) | PR | verdict | why | outcome |\n|---|---|---|---|---|\n| 2026-08-05T00:00Z | 15 | NO-GO | x | |\n' > "$TMP/led-nogo.md"
out="$( MERGE_GATE_LEDGER="$TMP/led-nogo.md" sh "$ROOT/tests/numbers-lint.sh" 2>&1 )"; rc=$?
assert "numbers-lint: NO-GO never counts as GO (the GO claim goes stale, not satisfied)" 1 "$rc" "$out" 'STALE.*GO row'

# The tagless branch: no local tags AND no reachable remote must SKIP visibly — not report real
# tags as STALE (the lint's own first CI run did exactly that on a shallow checkout), and not
# fail on what it cannot measure. A clone with a dead origin is the deterministic way to force it.
N=$((N+1)); NLD="$TMP/nl$N"
git clone -q --no-tags "file://$ROOT" "$NLD" 2>/dev/null
( cd "$NLD" && git remote set-url origin /nonexistent-remote )
out="$( cd "$NLD" && sh tests/numbers-lint.sh 2>&1 )"; rc=$?
assert "numbers-lint: tagless + dead remote → visible SKIP, no false STALE, exit 0" 0 "$rc" "$out" \
  'SKIP.*version references' 'STALE.*references v'

# ── catalog-variant.sh ──────────────────────────────────────────────────────────────────────────
# The three variant seeds are GENERATED from the baseline master (ADR-0004). A variant edited by
# hand — or a master edited without regenerating — is the exact drift class this repo documents
# everywhere else: a stale catalog reads like a current one. So every run re-derives all three
# and diffs them against the checked-in files. No drift can merge while this is red.
VGEN="$ROOT/.claude/skills/wai-init/scripts/catalog-variant.sh"
VREF="$ROOT/.claude/skills/wai-init/references"

echo
echo "catalog-variant.sh"
for v in platform web minimum; do
  out="$( cd "$ROOT" && sh "$VGEN" "$v" 2>&1 )"; rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "variant '$v' regenerates from the master" "exit $rc"
    printf '%s\n' "$out" | sed 's/^/         | /'
  elif d="$( printf '%s\n' "$out" | diff -u "$VREF/quality-attributes.$v.md" - )"; then
    ok "variant '$v' matches its checked-in file — no drift"
  else
    bad "variant '$v' matches its checked-in file — no drift" \
        "master and variant diverged — regenerate: sh catalog-variant.sh $v > references/quality-attributes.$v.md"
    printf '%s\n' "$d" | head -12 | sed 's/^/         | /'
  fi
done

out="$( cd "$ROOT" && sh "$VGEN" 2>&1 )"; rc=$?
assert "catalog-variant: a missing/unknown variant name is refused, exit 2" 2 "$rc" "$out" 'unknown variant'

# The derivation invariants the doctrine promises — checked on the OUTPUT, not assumed from the
# config: RES-3 survives every cut (the master's one scoping exception), and no dimension of a
# dropped concern leaks back in.
out="$( cd "$ROOT" && sh "$VGEN" minimum 2>&1 )"
assert "minimum keeps RES-3 — the scoping exception survives derivation" 0 0 "$out" \
  '^- \*\*RES-3 · '
assert "minimum carries no platform-only dimension" 0 0 "$out" \
  '' '^- \*\*(AI|PAY|IOS|AND|OBS|API|PERF|CLIENT|WEB)-'
out="$( cd "$ROOT" && sh "$VGEN" web 2>&1 )"
assert "web carries no AI / token-economy / store-surface dimension" 0 0 "$out" \
  '' '^- \*\*(AI|PAY|IOS|AND)-'

dead=""
for r in $(grep -rhoE 'references/[a-z0-9./-]+\.md' "$ROOT"/.claude/skills/*/SKILL.md | sort -u); do
  find "$ROOT/.claude/skills" -path "*/$r" | grep -q . || dead="$dead $r"
done
assert "no SKILL.md points at a reference that does not exist" 0 "$([ -z "$dead" ] && echo 0 || echo 1)" "dead:$dead"

strays="$(find "$ROOT/.claude/skills" -maxdepth 2 -name 'README.md' | tr '\n' ' ')"
assert "no README.md inside a skill folder" 0 "$([ -z "$strays" ] && echo 0 || echo 1)" "found: $strays"

echo
if [ "$SKIP" -gt 0 ]; then
  printf '%s passed, %s failed, %s SKIPPED — a skipped check is not a pass\n' "$PASS" "$FAIL" "$SKIP"
else
  printf '%s passed, %s failed\n' "$PASS" "$FAIL"
fi
[ "$FAIL" -eq 0 ]
