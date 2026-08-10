#!/usr/bin/env sh
# tests/scripts.sh — the eight scripts that shipped with no test at all.
#
# `tests/run.sh` opens with the stake: `merge-gate.sh` and `catalog-lint.sh` "are the ONLY
# deterministic things in this suite. Everything else is a prompt. If they are wrong, the thesis is
# wrong." That sentence now covers twenty-two scripts, and until this file existed EIGHT of them were
# unguarded — the whole wai-team batch, both audit linters, the contract lint, the issue miner
# and the handoff lint. All eight landed in one batch, and nobody ran them twice.
#
# That is not a hypothetical gap. BOTH field defects reported since that batch shipped came out of
# exactly this untested set:
#   · `mine-issues.sh` fragments every non-ASCII word at the umlaut. In a 63-issue German backlog
#     "Gebäude" — the strongest content signal in the repo — was mined as `geb` (df=8) AND `ude`
#     (df=11): two meaningless fragments whose counts contradict each other. The catalog author reads
#     that list and does not see the topic. (field report 2026-08-03)
#   · a test fixture that carried the very literal it tests tripped the suite's own pre-commit hook
#     and blocked a commit. So every fixture below that needs a secret-shaped or marker-shaped string
#     ASSEMBLES IT AT RUN TIME — the source of this file never holds the shape it tests.
#
# THE PASS PATH IS FIRST IN EVERY SECTION, for run.sh's reason and not a weaker one. Six of these
# eight can only fail closed: an emitter that never emits, a lint that never says OK, a barrier that
# never lifts. A gate you have never seen say GO is not a validated gate — it is an untested branch
# that happens to be failing closed, and this suite already ran one of those for months.
#
# AND THE OTHER HALF OF THE SAME COIN: three of these scripts exist BECAUSE they refuse to decide
# something (`has_ac_checkboxes` is a fact, not an actionability verdict; the contract lint's name
# heuristics advise and never gate; a withheld reason is quoted, never re-judged). A boundary nobody
# tests is a boundary the next edit walks through. Each one is asserted here as a must-NOT-match.
#
# FOUR CASES DELIBERATELY ASSERT A DEFECT instead of the behaviour we want. Each is marked KNOWN
# DEFECT, names the issue, and says what to change when it is repaired. A test that records today's
# answer is worth more than no test, and the fix belongs to a different PR. When one goes RED the bug
# was fixed: flip the case, do not silence it.
#   1. mine-issues.sh — a German word fragments at the umlaut (field report, 2026-08-03)
#   2. attack-path-lint.sh — it rejects its own skill's documented template
#   3. handoff-lint.sh — `grep -c` on an empty envelope leaks a shell error
#   4. handoff-lint.sh — a TRACKED file under temp/ also flips the ignore-RULE check to "missing",
#      so the lint prints a repair that fixes nothing. NEW: not in the audit; found by writing this
#      file, because the mutation that should have failed case 4's neighbour did not.
#
# Every fixture is built in a mktemp -d, `gh` is faked through PATH exactly as run.sh does, and no
# case touches the network or this repo. Run: sh tests/scripts.sh
set -u
[ -n "${ZSH_VERSION:-}" ] && exec /bin/sh "$0" "$@"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STUB="$ROOT/tests/stub"
MINE="$ROOT/.claude/skills/wai-init/scripts/mine-issues.sh"
CONTRACT="$ROOT/.claude/skills/wai-pr-review/scripts/contract-completeness.sh"
APLINT="$ROOT/.claude/skills/wai-security-audit/scripts/attack-path-lint.sh"
BACKLOG="$ROOT/.claude/skills/wai-team/scripts/backlog-scan.sh"
DIGEST="$ROOT/.claude/skills/wai-team/scripts/cross-issue-digest.sh"
PMV="$ROOT/.claude/skills/wai-team/scripts/post-merge-verify.sh"
AMR="$ROOT/.claude/skills/wai-team/scripts/autonomous-merge-report.sh"
HANDOFF="$ROOT/.claude/skills/wai/scripts/handoff-lint.sh"

# An ABSOLUTE interpreter. Several cases run a script under a deliberately crippled PATH ("gh is not
# installed"), and a shell found through $PATH cannot be started by a PATH that no longer has it.
SH="/bin/sh"

# `pwd -P` because $TMP is handed to GIT_CEILING_DIRECTORIES below, and git ignores a ceiling entry
# that contains a symlink — which /tmp and /var are on macOS.
TMP="$(mktemp -d)"; TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# Three of these scripts ask "am I in a git repository?" and answer by walking UP the tree. If this
# checkout's own parent ever held a .git, the "not a git repo → exit 2" cases would silently test
# nothing. The ceiling stops the walk at $TMP, so the answer is a property of the fixture.
GIT_CEILING_DIRECTORIES="$TMP"; export GIT_CEILING_DIRECTORIES

PASS=0; FAIL=0; XFAIL=0; N=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n         %s\n' "$1" "$2"; }

# assert NAME WANT-EXIT GOT-EXIT OUTPUT [MUST-MATCH] [MUST-NOT-MATCH]   (run.sh's helper, plus `-e`)
#
# `-e` is the one deviation from run.sh's copy, and it is not a style choice. A pattern that BEGINS
# WITH A DASH — `- post /widgets` is one, below — is read by grep as an option: the match never runs,
# grep exits 2, and the `elif` chain reads that as "did not match". For a MUST-MATCH that is a
# confusing failure; for a MUST-NOT-MATCH IT IS A SILENT PASS — the assertion is skipped and the test
# still says ok. That is the same bug handoff-lint.sh's own comment records against its secret
# pattern, one layer up, in the thing that decides whether the tests mean anything. `-e` is inert for
# every pattern that does not start with a dash, so it changes nothing else. (run.sh carries the same
# latent hole; it has no dash-leading pattern today.)
assert() {
  _n="$1"; _we="$2"; _ge="$3"; _out="$4"; _m="${5:-}"; _x="${6:-}"; _why=""
  if   [ "$_ge" != "$_we" ];                                          then _why="exit $_ge, wanted $_we"
  elif [ -n "$_m" ] && ! printf '%s\n' "$_out" | grep -qE -e "$_m";   then _why="no match for /$_m/"
  elif [ -n "$_x" ] &&   printf '%s\n' "$_out" | grep -qE -e "$_x";   then _why="matched /$_x/ and must not"
  fi
  if [ -z "$_why" ]; then ok "$_n"; else
    bad "$_n" "$_why"; printf '%s\n' "$_out" | sed 's/^/         | /'
  fi
}

# assert_xfail NAME WANT-EXIT GOT-EXIT OUTPUT [MUST-MATCH] [MUST-NOT-MATCH]
#
# Pins a KNOWN DEFECT: the arguments assert today's WRONG behaviour, verbatim. Two things make
# this its own verb instead of a green `ok`:
#   · Six pinned defects used to count as `ok` — a green that reads exactly like health, in the
#     file whose sibling calls that the worst kind of green. Pins now have their own column and
#     their own line in the summary, so the number cannot hide inside "passed".
#   · The day the defect stops reproducing, the pin FAILS — an XPASS is not a pass. A fix that
#     landed without updating its pin would otherwise leave a stale assertion of brokenness that
#     nothing ever reads again. The failure text says what to do next.
assert_xfail() {
  _n="$1"; _we="$2"; _ge="$3"; _out="$4"; _m="${5:-}"; _x="${6:-}"; _why=""
  if   [ "$_ge" != "$_we" ];                                          then _why="exit $_ge, wanted $_we"
  elif [ -n "$_m" ] && ! printf '%s\n' "$_out" | grep -qE -e "$_m";   then _why="no match for /$_m/"
  elif [ -n "$_x" ] &&   printf '%s\n' "$_out" | grep -qE -e "$_x";   then _why="matched /$_x/ and must not"
  fi
  if [ -z "$_why" ]; then
    XFAIL=$((XFAIL+1)); printf '  XFAIL %s\n' "$_n"
  else
    bad "XPASS: $_n" "the pinned defect no longer reproduces ($_why) — promote this pin to a regular assert and close its issue"
    printf '%s\n' "$_out" | sed 's/^/         | /'
  fi
}

# ── the fake gh ──────────────────────────────────────────────────────────────────────────────────
# tests/stub/gh already fakes the verbs merge-gate.sh uses. It does not know `issue list`,
# `issue view` or `pr list`, which is all four wai-team scripts and the issue miner. Rather than
# fork a second fake gh — two copies of the same lie, one of them always out of date — this EXTENDS
# it: the new verbs here, everything else exec'd straight through to the shipped stub.
GHBIN="$TMP/ghbin"; mkdir -p "$GHBIN"
GH_SHIPPED_STUB="$STUB/gh"; export GH_SHIPPED_STUB
cat > "$GHBIN/gh" <<'GHSTUB'
#!/usr/bin/env sh
# An extension of tests/stub/gh, same contract: emit what the real gh emits AFTER `--jq` has run,
# read from files in $GH_FIXTURE. Two things it must get right, because the real gh does:
#   1. `gh issue list` is called with FOUR different --json field sets by four different callers, and
#      each expects a different post-jq shape. Keying on the field set is what makes the fixture the
#      script's actual input instead of a shape the stub made up.
#   2. gh FAILING and gh printing NOTHING are different answers — backlog-scan turns the first into
#      UNKNOWN and the second into "empty backlog", and folding them is the bug it guards. Both are
#      reachable: `issue-list-fail` for the first, an absent fixture file for the second.
set -u
F="${GH_FIXTURE:?GH_FIXTURE not set}"
SHIPPED="${GH_SHIPPED_STUB:?GH_SHIPPED_STUB not set}"
emit() { [ -f "$F/$1" ] && cat "$F/$1"; return 0; }
# Same call log as the shipped stub, so a test can assert not just what came back but that the
# caller ASKED the way it claims to. Only for the verbs handled here — the delegated ones are logged
# by the shipped stub itself, and logging both ends would double every delegated call.
logcall() { printf '%s\n' "$*" >> "$F/gh-calls.log" 2>/dev/null || true; }

case "${1:-}" in
  auth)
    logcall "$@"
    [ -f "$F/auth-fail" ] && exit 1
    exit 0 ;;
  issue)
    logcall "$@"
    case "${2:-}" in
      list)
        [ -f "$F/issue-list-fail" ] && exit 3
        case "$*" in
          *assignees*)         emit backlog ;;
          *updatedAt*)         emit issue-index ;;
          *number,title,body*) emit issue-titles ;;
          *number,labels*)     emit issue-labels ;;
          *number,title*)      emit issue-titles ;;
        esac ;;
      view)
        [ -f "$F/issue-${3:-}" ] || exit 1
        cat "$F/issue-${3:-}" ;;
    esac ;;
  pr)
    case "${2:-}" in
      list)
        logcall "$@"
        case "$*" in
          *number,labels*) emit pr-labels ;;
          *number,title*)  emit pr-titles ;;
        esac ;;
      *) exec "$SHIPPED" "$@" ;;
    esac ;;
  *) exec "$SHIPPED" "$@" ;;
esac
exit 0
GHSTUB
chmod +x "$GHBIN/gh"

# A PATH with NO gh on it, and one with git but no gh (mine-issues checks git BEFORE gh, so the
# "gh is missing" case must still be able to answer the git question).
NOGH="$TMP/nogh"; mkdir -p "$NOGH"
GITONLY="$TMP/gitonly"; mkdir -p "$GITONLY"
GITBIN="$(command -v git 2>/dev/null || echo /usr/bin/git)"
ln -sf "$GITBIN" "$GITONLY/git"

# ── throwaway git repos ──────────────────────────────────────────────────────────────────────────
# Hooks OFF, identity pinned. This repo ships a pre-commit hook that refuses commits on the default
# branch — a fresh fixture repo IS on its default branch — and the developer running this may have
# any global hook installed. A fixture must not depend on either.
NOHOOKS="$TMP/nohooks"; mkdir -p "$NOHOOKS"
gitrepo() {   # $1 = dir
  mkdir -p "$1"
  git -C "$1" -c init.defaultBranch=main init -q >/dev/null 2>&1
  git -C "$1" config user.email 'fixture@example.invalid'
  git -C "$1" config user.name  'Fixture'
  git -C "$1" config commit.gpgsign false
  git -C "$1" config core.hooksPath "$NOHOOKS"
}
gitcommit() { # $1 = dir, $2 = subject
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" commit -q --allow-empty -m "$2" >/dev/null 2>&1
}

# =================================================================================================
echo "mine-issues.sh"
# The read-only signal an existing backlog carries. It emits COUNTS and example issue NUMBERS, and
# it decides nothing — the catalog author does. 0 = emitted (an empty backlog IS emitted), 2 = the
# signal is unreachable (degrade to code-only mining), 3 = misuse.
# =================================================================================================

mifix() {   # a git repo gh can resolve, with a small backlog
  N=$((N+1)); D="$TMP/mi$N"; gitrepo "$D"
  printf 'acme/repo\n' > "$D/repo"
  printf 'bug\t11\nbug\t12\nperf\t12\n'                                  > "$D/issue-labels"
  printf '11\ttimeout on report export\n12\ttimeout when uploading\n13\tflaky timeout in checkout\n' \
                                                                         > "$D/issue-titles"
  printf 'chore\t20\n'                                                   > "$D/pr-labels"
  printf '20\tfix the checkout timeout for good\n'                       > "$D/pr-titles"
}
mine() { ( cd "$D" && PATH="$GHBIN:$STUB:$PATH" GH_FIXTURE="$D" sh "$MINE" "$@" 2>&1 ); }

# THE PASS PATH. An emitter nobody has watched emit is not an emitter.
mifix; out="$(mine)"; rc=$?
assert "a backlog emits LABEL_FREQ with example NUMBERS → exit 0" 0 "$rc" "$out" 'LABEL_FREQ label="bug" count=2 examples=#1'
assert "TERM_DF is a DOCUMENT frequency, not a word count (3 issues say timeout → df=3)" 0 "$rc" "$out" 'TERM_DF term="timeout" df=3'
assert "closed PRs are mined as their own theme stream" 0 "$rc" "$out" 'CLOSED_PR_THEMES (label|term)='
# THE BOUNDARY. Everything else in this suite that prints a VERDICT has decided something. This
# script must not: the extend / mint-a-local-ID / propose-upstream / drop call is the model's.
assert "it emits evidence and renders NO verdict" 0 "$rc" "$out" 'COUNTS are evidence, not a verdict' 'VERDICT'

# An empty backlog is a real answer — a new repo has no history. It must SAY so, because silence
# here reads as "mined and found nothing" when it may mean "never ran".
mifix; rm -f "$D/issue-labels" "$D/issue-titles" "$D/pr-labels" "$D/pr-titles"
out="$(mine)"; rc=$?
assert "an EMPTY backlog is valid and says so → exit 0" 0 "$rc" "$out" 'LABEL_FREQ \(none.*TERM_DF \(none|no issues in range'

# ── KNOWN DEFECT (field report 2026-08-03, issue mining) ────────────────────
# `tr -cs 'a-z0-9'` treats every non-ASCII byte as a separator, so a German word is mined as the
# fragments on either side of its umlaut. "Gebäude" → `geb` + `ude`, neither of which means anything
# and whose df counts disagree. Asserted as it behaves TODAY, deliberately, so the repair has a
# denominator. DO NOT "fix" this case — fix mine-issues.sh, then flip these two lines to assert
# `TERM_DF term="gebäude"` and delete the fragments.
mifix; printf '31\tGeb\303\244ude im Report fehlt\n32\tGeb\303\244ude-Liste ist leer\n' > "$D/issue-titles"
out="$(mine)"; rc=$?
assert_xfail "KNOWN DEFECT: a German word FRAGMENTS at the umlaut (geb + ude, not gebäude)" 0 "$rc" "$out" 'TERM_DF term="ude" df=2'
assert_xfail "KNOWN DEFECT: and the two halves are counted as separate terms" 0 "$rc" "$out" 'TERM_DF term="geb" df=2'

# Unreachable signal ≠ clean backlog. All three of these degrade the CALLER to code-only mining;
# none of them is a statement about this repo.
mifix; out="$( cd "$D" && PATH="$GITONLY" GH_FIXTURE="$D" "$SH" "$MINE" 2>&1 )"; rc=$?
assert "gh not installed → UNKNOWN, exit 2 (degrade, never 'empty backlog')" 2 "$rc" "$out" 'gh is not installed.*degrade'

mifix; : > "$D/auth-fail"; out="$(mine)"; rc=$?
assert "gh not authenticated → UNKNOWN, exit 2" 2 "$rc" "$out" 'not authenticated.*degrade'

mifix; : > "$D/repo-fail"; out="$(mine)"; rc=$?
assert "origin is not a GitHub repo gh can resolve → UNKNOWN, exit 2" 2 "$rc" "$out" 'origin is not a GitHub repo'

# MISUSE IS 2, NOT A PRIVATE THIRD CODE. "You ran me in the wrong place" and "I could not
# reach GitHub" want different repairs from the caller.
N=$((N+1)); D="$TMP/mi-nogit$N"; mkdir -p "$D"
out="$( cd "$D" && PATH="$GHBIN:$STUB:$PATH" GH_FIXTURE="$D" sh "$MINE" 2>&1 )"; rc=$?
assert "not a git repository → exit 2 (UNKNOWN — misuse and unreachable share one decision)" 2 "$rc" "$out" 'not a git repository'

mifix; out="$(mine --bogus)"; rc=$?
assert "an unknown argument → exit 2, never a silent partial mine" 2 "$rc" "$out" 'unknown argument'

# =================================================================================================
echo
echo "contract-completeness.sh"
# The structural floor drives the exit; the name heuristics are guesses from a NAME and may never
# move it. 0 = floor met, 1 = a hole, 2 = not a document this line reader can read.
# =================================================================================================

# One generator, six variants. The `ok` spec meets all four floors AND trips no heuristic, so any
# advisory that shows up in the other variants is provably the variant's doing.
cspec() {   # $1 = variant: ok | warnbait | no4xx | noerrdef | nosecdef | nosecop | opsec | noversion
  N=$((N+1)); SPEC="$TMP/spec$N.yaml"; V="$1"
  cat > "$SPEC" <<'EOF'
openapi: 3.0.3
info:
  title: Widgets
EOF
  if [ "$V" != noversion ]; then
    cat >> "$SPEC" <<'EOF'
  version: 1.0.0
EOF
  fi
  # A global security requirement covers every operation. The `opsec` variant drops it to exercise
  # the per-operation path instead; `nosecdef` drops the whole surface.
  if [ "$V" != nosecdef ] && [ "$V" != nosecop ] && [ "$V" != opsec ]; then
    cat >> "$SPEC" <<'EOF'
security:
  - bearerAuth: []
EOF
  fi
  cat >> "$SPEC" <<'EOF'
paths:
  /widgets:
    get:
      summary: list widgets
      responses:
        '200':
          description: ok
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Widget'
        '400':
          description: bad request
EOF
  if [ "$V" != no4xx ]; then
    cat >> "$SPEC" <<'EOF'
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
EOF
  fi
  cat >> "$SPEC" <<'EOF'
    post:
      summary: create a widget
EOF
  if [ "$V" != warnbait ]; then
    cat >> "$SPEC" <<'EOF'
      parameters:
        - name: Idempotency-Key
          in: header
          required: true
          schema:
            type: string
EOF
  fi
  if [ "$V" = opsec ]; then
    cat >> "$SPEC" <<'EOF'
      security:
        - bearerAuth: []
EOF
  fi
  cat >> "$SPEC" <<'EOF'
      responses:
        '201':
          description: created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Widget'
        '422':
          description: invalid
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
components:
EOF
  if [ "$V" != nosecdef ]; then
    cat >> "$SPEC" <<'EOF'
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
EOF
  fi
  cat >> "$SPEC" <<'EOF'
  schemas:
EOF
  if [ "$V" != noerrdef ]; then
    cat >> "$SPEC" <<'EOF'
    Error:
      type: object
      properties:
        code:
          type: string
        message:
          type: string
EOF
  fi
  if [ "$V" = warnbait ]; then
    # Every name heuristic tripped at once: a money name typed float, a closed-set name with no
    # enum, a timestamp name with no format — and, via the dropped parameters block above, a
    # mutating op with no idempotency key.
    cat >> "$SPEC" <<'EOF'
    Widget:
      type: object
      properties:
        id:
          type: string
        amount:
          type: number
        status:
          type: string
        created_at:
          type: string
EOF
  else
    cat >> "$SPEC" <<'EOF'
    Widget:
      type: object
      properties:
        id:
          type: string
        amount_minor:
          type: integer
        status:
          type: string
          enum: [active, retired]
        created_at:
          type: string
          format: date-time
EOF
  fi
}

# THE PASS PATH. A contract lint that has never said OK gets routed around on its first false alarm.
cspec ok; out="$(sh "$CONTRACT" "$SPEC" 2>&1)"; rc=$?
assert "a spec meeting the structural floor → OK, exit 0" 0 "$rc" "$out" 'VERDICT: OK'
assert "and the clean spec trips no name heuristic either" 0 "$rc" "$out" 'no name-heuristic advisories'

cspec opsec; out="$(sh "$CONTRACT" "$SPEC" 2>&1)"; rc=$?
assert "no global security, but every mutating op declares its own → OK, exit 0" 0 "$rc" "$out" 'every mutating op requires one'

# ── THE ASSERTION THIS SECTION EXISTS FOR ────────────────────────────────────────────────────────
# The heuristics are guesses from a FIELD NAME. The day one of them moves the exit code, the lint
# starts failing merges over a naming convention it does not own — and a gate that cries wolf gets
# switched off (ADR-0002). All four fire here at once, and the verdict must not move a millimetre.
cspec warnbait; out="$(sh "$CONTRACT" "$SPEC" 2>&1)"; rc=$?
assert "all four name heuristics fire → still exit 0, still VERDICT: OK" 0 "$rc" "$out" 'VERDICT: OK' 'VERDICT: FAILED'
assert "  · money-named float is a WARNING" 0 "$rc" "$out" '⚠ money-named field\(s\).*amount'
assert "  · closed-set string without enum is a WARNING" 0 "$rc" "$out" '⚠ closed-set-named string\(s\) with no enum.*status'
assert "  · timestamp without format: date-time is a WARNING" 0 "$rc" "$out" '⚠ timestamp-named field\(s\).*created_at'
assert "  · a mutating op with no idempotency key is a WARNING" 0 "$rc" "$out" '⚠ mutating op\(s\) with no idempotency key'
assert "and the advisories are labelled as a human's call, not a gate" 0 "$rc" "$out" 'never gate — a human reads these'

# The structural floor, one hole at a time.
cspec no4xx; out="$(sh "$CONTRACT" "$SPEC" 2>&1)"; rc=$?
assert "a 4xx with a description and no schema → FAILED, exit 1" 1 "$rc" "$out" 'no body schema.*400'

cspec noerrdef; out="$(sh "$CONTRACT" "$SPEC" 2>&1)"; rc=$?
assert "responses \$ref an error envelope that is never defined → FAILED, exit 1" 1 "$rc" "$out" 'no component schema named'

cspec nosecop; out="$(sh "$CONTRACT" "$SPEC" 2>&1)"; rc=$?
assert "a MUTATING op requiring no security, with no global security → FAILED, exit 1" 1 "$rc" "$out" 'MUTATING op\(s\) require none' 'VERDICT: OK'
assert "and it names the operation, so the hole is repairable" 1 "$rc" "$out" '- post /widgets'

cspec nosecdef; out="$(sh "$CONTRACT" "$SPEC" 2>&1)"; rc=$?
assert "no security scheme defined at all → FAILED, exit 1" 1 "$rc" "$out" 'no security scheme is defined'

cspec noversion; out="$(sh "$CONTRACT" "$SPEC" 2>&1)"; rc=$?
assert "no info.version → FAILED, exit 1 (a consumer cannot pin, or detect a breaking bump)" 1 "$rc" "$out" 'no API version'

# UNKNOWN, never a green it did not earn. This is a LINE reader; a minified document is not a
# document it can read, and reading zero `paths:` out of one is not "a spec with no holes".
N=$((N+1)); MIN="$TMP/min$N.json"
printf '{"openapi":"3.0.3","info":{"title":"W","version":"1"},"paths":{"/w":{"get":{"responses":{"200":{"description":"ok"}}}}}}\n' > "$MIN"
out="$(sh "$CONTRACT" "$MIN" 2>&1)"; rc=$?
assert "a MINIFIED one-line spec → UNKNOWN, exit 2 (never a false pass)" 2 "$rc" "$out" 'not an OpenAPI doc this reader can parse' 'VERDICT: (OK|FAILED)'

out="$(sh "$CONTRACT" "$TMP/does-not-exist.yaml" 2>&1)"; rc=$?
assert "an unreadable spec → UNKNOWN, exit 2" 2 "$rc" "$out" 'cannot read spec'

# =================================================================================================
echo
echo "attack-path-lint.sh"
# It validates FORM, never TRUTH. 0 = well-formed (or nothing to chain), 1 = malformed/mis-linked,
# 2 = the report could not be read.
# =================================================================================================

apnew() { N=$((N+1)); REP="$TMP/ap$N.md"; cat > "$REP"; }

# THE PASS PATH. Note `objective reached:` on the AP-1 line — the literal token is what satisfies the
# objective-line check today. See the KNOWN DEFECT case at the end of this section.
apnew <<'EOF'
# Security audit — 2026-08-03

**Posture:** Hardening needed

### Findings
#### Blocker
- [F1] · apps/api/src/auth/session.ts · `SEC-1` · new — a forged cookie is accepted → takeover → verify it  (redacted)
#### Major
- [F2] · apps/api/src/reports.ts · `SEC-8` · new — report id is not tenant-scoped → cross-tenant read → scope it  (redacted)
#### Minor
- [F3] · apps/web/src/app/error.tsx · `MAINT-1` · new — the stack trace renders → internals disclosed → strip it  (redacted)

### Attack paths (kill-chains)
- AP-1 · Blocker · new — objective reached: another tenant's ledger
  1. [F1] entry — crosses the public edge · reachable: unauthenticated
  2. [F2] pivot — crosses the tenant boundary · reachable: ids are sequential   ⛓✂ cheapest to break
  ↑ chain severity above its links: composition turns a Major into a takeover
- Standalone (reach no objective yet): [F3] — hardening, ranked below the chains.
EOF
out="$(sh "$APLINT" "$REP" 2>&1)"; rc=$?
assert "a well-formed Attack paths section → OK, exit 0" 0 "$rc" "$out" 'VERDICT: OK'
assert "every cited F-handle resolves (the ADR-0003 renumber guard)" 0 "$rc" "$out" 'every cited F-handle \(3\) resolves'
assert "a Blocker in a chain and a Minor on the Standalone line are both accounted for" 0 "$rc" "$out" 'every Blocker/Major finding is accounted for'
# The boundary it advertises: a tidy chain that is FICTION passes clean, and it says so on every run.
assert "it states it validates FORM, not TRUTH — on the passing run too" 0 "$rc" "$out" 'VALIDATES FORM.*NOT TRUTH'

# A handle that points at nothing. This is the renumber hazard made concrete: a finding is dropped or
# renumbered and the chain now cites a finding that does not exist — or, worse, someone else's.
apnew <<'EOF'
### Findings
#### Blocker
- [F1] · a.ts · `SEC-1` · new — x → y → z  (redacted)
#### Major
- [F2] · b.ts · `SEC-8` · new — x → y → z  (redacted)

### Attack paths (kill-chains)
- AP-1 · Blocker · new — objective reached: the ledger
  1. [F1] entry — crosses the edge · reachable: yes
  2. [F2] pivot — crosses the boundary · reachable: yes   ⛓✂ cheapest to break
  3. [F9] landing — reachable: yes
EOF
out="$(sh "$APLINT" "$REP" 2>&1)"; rc=$?
assert "a chain citing a handle that resolves to NO finding → FAILED, exit 1" 1 "$rc" "$out" 'resolve to NO finding: F9' 'VERDICT: OK'

# The synthesis must not quietly drop a Blocker. Every Blocker/Major is chained OR on the Standalone
# line; there is no third place for it to be.
apnew <<'EOF'
### Findings
#### Blocker
- [F1] · a.ts · `SEC-1` · new — x → y → z  (redacted)
- [F4] · d.ts · `SEC-3` · new — the one nobody synthesised  (redacted)

### Attack paths (kill-chains)
- AP-1 · Blocker · new — objective reached: the ledger
  1. [F1] entry — crosses the edge · reachable: yes   ⛓✂ cheapest to break
EOF
out="$(sh "$APLINT" "$REP" 2>&1)"; rc=$?
assert "a Blocker in no chain and not standalone → FAILED, exit 1" 1 "$rc" "$out" 'neither chained nor listed standalone: F4'

# No Attack paths section at all is VALID — when there is nothing that had to be accounted for.
apnew <<'EOF'
### Findings
#### Minor
- [F1] · a.ts · `MAINT-1` · new — a nit  (redacted)
EOF
out="$(sh "$APLINT" "$REP" 2>&1)"; rc=$?
assert "no Attack paths section and no Blocker/Major → OK, exit 0, and says so" 0 "$rc" "$out" 'nothing to chain'

# …and invalid the moment there IS. A Blocker with nowhere to be is the failure, not the missing
# heading.
apnew <<'EOF'
### Findings
#### Blocker
- [F1] · a.ts · `SEC-1` · new — x → y → z  (redacted)
EOF
out="$(sh "$APLINT" "$REP" 2>&1)"; rc=$?
assert "a Blocker exists but there is NO Attack paths section → FAILED, exit 1" 1 "$rc" "$out" 'no .### Attack paths. section'

# A section with only prose/standalone and no AP-<n> block is valid: not every audit finds a chain.
apnew <<'EOF'
### Findings
#### Minor
- [F1] · a.ts · `MAINT-1` · new — a nit  (redacted)

### Attack paths (kill-chains)
- Standalone (reach no objective yet): [F1] — nothing composes into a chain this round.
EOF
out="$(sh "$APLINT" "$REP" 2>&1)"; rc=$?
assert "an Attack paths section with NO chain block → OK, exit 0, and says why that is valid" 0 "$rc" "$out" 'no AP-<n> chain block'

# Cited catalog IDs are an ADVISORY and only when a catalog is passed. This lint owns form; it does
# not get to fail a report because a catalog was tailored (that is catalog-lint's whole lesson).
apnew <<'EOF'
### Findings
#### Minor
- [F1] · a.ts · `MAINT-1` · new — a nit  (redacted)

### Attack paths (kill-chains)
- AP-1 · Minor · new — objective reached: nothing much, cited as `PAY-9`
  1. [F1] entry — crosses the edge · reachable: yes   ⛓✂ cheapest to break
EOF
N=$((N+1)); CATF="$TMP/cat$N.md"; printf -- '- **SEC-1 · Auth** — a. *Red Flag:* b.\n' > "$CATF"
out="$(sh "$APLINT" "$REP" "$CATF" 2>&1)"; rc=$?
assert "a cited catalog ID that does not resolve is ADVISORY, not a form failure → exit 0" 0 "$rc" "$out" '⚠ cited catalog ID\(s\) not found' 'VERDICT: FAILED'

out="$(sh "$APLINT" "$TMP/no-such-report.md" 2>&1)"; rc=$?
assert "an unreadable report → UNKNOWN, exit 2" 2 "$rc" "$out" 'cannot read report' 'VERDICT'

out="$(sh "$APLINT" 2>&1)"; rc=$?
assert "no report argument → UNKNOWN, exit 2" 2 "$rc" "$out" 'no report given'

# ── KNOWN DEFECT (audit 2026-08-03) ─────────────────────────────────────────────────────────
# The block below is wai-security-audit's OWN documented template with its placeholders filled
# in as the template instructs: `— [objective reached]` becomes the objective that was reached, and
# `3. [F<c>] [objective]` becomes the landing step. Filled in, the literal token "objective" is gone
# — and the lint requires that literal, so it rejects the exact shape its own skill tells the auditor
# to write. Asserted as it behaves TODAY. Fix attack-path-lint.sh (recognise the template's shape,
# or drop the objective-line check), then flip this case to expect exit 0.
apnew <<'EOF'
### Findings
#### Blocker
- [F1] · apps/api/src/auth/session.ts · `SEC-1` · new — forged cookie → takeover → verify it  (redacted)
#### Major
- [F2] · apps/api/src/reports.ts · `SEC-8` · new — id not tenant-scoped → cross-tenant read → scope it  (redacted)

### Attack paths (kill-chains)
- AP-1 · Blocker · new — another tenant's ledger is read end to end
  1. [F1] a forged cookie is accepted — crosses the public edge · reachable: unauthenticated
  2. [F2] the report id is not scoped — crosses the tenant boundary · reachable: ids are sequential   ⛓✂ cheapest to break
  ↑ chain severity above its links: two findings compose into a full cross-tenant read
EOF
out="$(sh "$APLINT" "$REP" 2>&1)"; rc=$?
assert_xfail "KNOWN DEFECT: the skill's OWN template, filled in, is rejected (no literal 'objective')" 1 "$rc" "$out" 'AP-1 is missing:.*objective-line'

# =================================================================================================
echo
echo "backlog-scan.sh"
# The proposal a team run stops on. 0 = overview produced (an empty backlog IS an overview),
# 2 = UNKNOWN. There is no exit 1: this script renders no negative verdict.
# =================================================================================================

# `~` is the placeholder for the 0x1C field separator the real --jq emits, translated at write time —
# a control byte in a fixture literal is unreadable and travels badly through an editor.
bkfix() {
  N=$((N+1)); D="$TMP/bk$N"; mkdir -p "$D"
  printf '%s\n' \
    '12~fix the export timeout~~bug~Repro steps here. - [ ] add a regression test' \
    '13~refactor the billing charge path~alice~size:M~Cleanup. depends on #12 first.' \
    | tr '~' '\034' > "$D/backlog"
}
scan() { ( cd "$D" && PATH="$GHBIN:$STUB:$PATH" GH_FIXTURE="$D" sh "$BACKLOG" "$@" 2>&1 ); }

bkfix; out="$(scan)"; rc=$?
assert "an open backlog → overview, exit 0" 0 "$rc" "$out" '2 open issue\(s\)'
assert "the frontier is computed, not eyeballed: #12 has no open blocker → order=1" 0 "$rc" "$out" '#12  order=1  frontier=yes  unclaimed'
assert "#13 depends on an OPEN #12 → off the frontier, and the claim is reported" 0 "$rc" "$out" '#13  order=2  frontier=no  claimed:alice  size=size:M'
assert "an open blocker is named, not just counted" 0 "$rc" "$out" 'blockers=#12 \(open: #12\)'

# ── THE ASSERTION THIS SECTION EXISTS FOR ────────────────────────────────────────────────────────
# `has_ac_checkboxes` is the presence of a `- [ ]` line and NOTHING ELSE. A checklist-free issue can
# be perfectly workable and a checklist-heavy one can be noise, so the drop/keep call stays with the
# model. The day this emits `actionable=no`, a mechanical signal has put on a verdict's clothes.
assert "has_ac_checkboxes is emitted as a mechanical FACT for both issues" 0 "$rc" "$out" 'has_ac_checkboxes=yes.*|has_ac_checkboxes=no'
assert "and it renders NO actionability verdict anywhere" 0 "$rc" "$out" 'mechanical fact' 'actionable[=:]|not actionable'
# Same shape one column over: an issue carries no diff, so the exclusion hint can only WIDEN. The
# authoritative call is excluded-domains.sh on the PR, and this output must not read as a clearance.
assert "the exclusion domain is a HINT from issue text, and says the PR diff is the authority" 0 "$rc" "$out" 'exclusion_domain_hint=billing'
assert "  · and it is labelled advisory, widening only" 0 "$rc" "$out" 'this hint only WIDENS'
assert "backlog-scan renders no verdict of its own (it reports; the human mandates)" 0 "$rc" "$out" 'PROPOSAL' 'VERDICT'

# Zero open issues is an ANSWER. It must not be silent, or "nothing to work" is indistinguishable
# from "never scanned".
bkfix; rm -f "$D/backlog"; out="$(scan)"; rc=$?
assert "an EMPTY backlog → exit 0, and says an empty backlog is valid" 0 "$rc" "$out" 'no open issues.*|empty backlog is a valid answer'

bkfix; out="$(scan ready-for-agent)"; rc=$?
assert "a label filter is reported in the header, so the scope of the proposal is visible" 0 "$rc" "$out" 'label: ready-for-agent'
# …and it actually REACHED gh. Printing the filter in the header while listing the whole backlog is
# the "advertised and never passed on" defect the shipped stub's call log was added for: the answer
# looks right, and the scope of the proposal is silently wrong.
assert "  · and the filter was really passed to gh, not just printed" 0 "$rc" "$(cat "$D/gh-calls.log" 2>&1)" 'issue list .*--label ready-for-agent'

bkfix; out="$( cd "$D" && PATH="$NOGH" GH_FIXTURE="$D" "$SH" "$BACKLOG" 2>&1 )"; rc=$?
assert "gh not installed → UNKNOWN, exit 2" 2 "$rc" "$out" 'gh is not installed'

bkfix; : > "$D/auth-fail"; out="$(scan)"; rc=$?
assert "gh not authenticated → UNKNOWN, exit 2" 2 "$rc" "$out" 'not authenticated'

# THE FOLD THAT WOULD BE SILENT. A failed listing and an empty backlog both produce zero records. If
# they were folded, a transient auth failure would read as "nothing to work" — a wrong all-clear that
# nobody could see. The exit STATUS of the call is the arbiter, checked before the content.
bkfix; : > "$D/issue-list-fail"; out="$(scan)"; rc=$?
assert "gh listing FAILED → UNKNOWN, exit 2 — never 'no open issues'" 2 "$rc" "$out" 'could not list issues' 'no open issues'

# =================================================================================================
echo
echo "cross-issue-digest.sh"
# The notes a run left on OTHER people's issues, gathered so none evaporates. 0 = digest produced
# (an empty one is a real answer), 2 = UNKNOWN (unbounded → not produced).
# =================================================================================================

dgfix() {
  N=$((N+1)); D="$TMP/dg$N"; mkdir -p "$D"
  # number <TAB> updatedAt <TAB> title. #12 and #123 are the near-miss pair, titled by LENGTH and not
  # by role, because each of them plays both roles below.
  printf '12\t2026-08-03T13:00:00Z\tthe short number\n'                              > "$D/issue-index"
  printf '123\t2026-08-03T13:05:00Z\tthe long number\n'                             >> "$D/issue-index"
  printf '44\t2026-08-01T09:00:00Z\ttouched before the run started\n'               >> "$D/issue-index"
  printf '77\t2026-08-03T13:10:00Z\tthe issue gh cannot read this run\n'            >> "$D/issue-index"
  printf 'BODY\t12\tRaised while looking at #99.\n'                                  > "$D/issue-12"
  printf 'BODY\t123\tSeen while working #12; this one depends on #12 as well.\n'     > "$D/issue-123"
  printf 'CMT\t123\t2026-08-03T13:05:00Z\tSame timeout shows up here too.\n'        >> "$D/issue-123"
  # no $D/issue-77 on purpose: a per-issue fetch failure is a gap on ONE issue, not a run failure.
}
digest() { ( cd "$D" && PATH="$GHBIN:$STUB:$PATH" GH_FIXTURE="$D" sh "$DIGEST" "$@" 2>&1 ); }

dgfix; out="$(digest 2026-08-03T12:00:00Z 12)"; rc=$?
assert "a digest of activity outside the worked set → exit 0" 0 "$rc" "$out" 'the long number'
assert "the worked issue itself IS excluded (it is the run's own output, not a cross-issue note)" 0 "$rc" "$out" 'OUTSIDE the worked set' 'the short number'
assert "an issue touched BEFORE the run start is outside the window" 0 "$rc" "$out" '#123' 'touched before the run started'
assert "a reference pointing back INTO the worked set is marked, as a hint" 0 "$rc" "$out" '#12\*'
assert "one unreadable issue is a noted gap, not a run failure" 0 "$rc" "$out" '#77 — could not read'
assert "the digest is raw material and says so — it files nothing" 0 "$rc" "$out" 'RAW material.*not the section itself' 'VERDICT'

# ── THE ASSERTION THIS SECTION EXISTS FOR ────────────────────────────────────────────────────────
# The worked set is matched as a whole NUMBER, and this is the direction that proves it. `index(ws,
# num)` — the obvious way to write it — is TRUE for num=12 against a worked set holding 123, so a run
# that worked #123 would drop every note left on #12, #23, #3. It fails SILENTLY in the one shape
# nobody can audit: the digest is a list of things that are supposed to be there, and nobody counts
# the absences. (The reverse pair, worked=12 against candidate #123, is asserted above and passes
# under the naive implementation too — it is not the binding case, which is exactly why both are here.)
dgfix; out="$(digest 2026-08-03T12:00:00Z 123)"; rc=$?
assert "a worked set of 123 does NOT swallow #12 — whole-number match, not substring" 0 "$rc" "$out" 'the short number' 'the long number'

# Touched but silent ≠ nothing touched. An issue that was updated with no reference, relation or
# comment text is not a candidate, and the report must not go quiet about that.
dgfix; printf '55\t2026-08-03T13:00:00Z\ttouched but carries no textual signal\n' > "$D/issue-index"
printf 'BODY\t55\t\n' > "$D/issue-55"
out="$(digest 2026-08-03T12:00:00Z 12)"; rc=$?
assert "candidates with no textual signal → exit 0, and the emptiness is explained" 0 "$rc" "$out" 'none carried a #-reference'

dgfix; : > "$D/issue-index"; out="$(digest 2026-08-03T12:00:00Z 12)"; rc=$?
assert "an EMPTY digest is a valid answer → exit 0, and says so" 0 "$rc" "$out" 'empty digest is a valid answer'

dgfix; out="$(digest)"; rc=$?
assert "no run-start / worked-set → UNKNOWN, exit 2 (the digest cannot be bounded)" 2 "$rc" "$out" 'cannot bound the digest'

dgfix; out="$(digest 2026-08-03T12:00:00Z)"; rc=$?
assert "a worked set with no start timestamp → UNKNOWN, exit 2" 2 "$rc" "$out" 'cannot bound the digest'

dgfix; out="$( cd "$D" && PATH="$NOGH" GH_FIXTURE="$D" "$SH" "$DIGEST" 2026-08-03T12:00:00Z 12 2>&1 )"; rc=$?
assert "gh not installed → UNKNOWN, exit 2" 2 "$rc" "$out" 'gh is not installed'

dgfix; : > "$D/auth-fail"; out="$(digest 2026-08-03T12:00:00Z 12)"; rc=$?
assert "gh not authenticated → UNKNOWN, exit 2" 2 "$rc" "$out" 'not authenticated'

dgfix; : > "$D/issue-list-fail"; out="$(digest 2026-08-03T12:00:00Z 12)"; rc=$?
assert "gh listing FAILED → UNKNOWN, exit 2 — never an empty digest" 2 "$rc" "$out" 'could not list issues' 'empty digest is a valid answer'

# =================================================================================================
echo
echo "post-merge-verify.sh"
# The hard serial barrier between one autonomous merge and the next. 0 = green (the barrier lifts),
# 1 = RED, 2 = UNKNOWN. Both 1 and 2 STOP the run; they are different repairs, not different moods.
# The test command is a trivial one we own — the barrier's contract is about resolve/run/report,
# not about any ecosystem's runner.
# =================================================================================================

pmvfix() {   # a repo with one commit; NOTE: no package.json / Cargo.toml / tests-dir, so the
  N=$((N+1)); D="$TMP/pmv$N"; gitrepo "$D"   # auto-detector finds nothing unless we hand it TEST_CMD
  printf '# fixture\n' > "$D/README.md"
  gitcommit "$D" 'chore: baseline'
  SHA="$(git -C "$D" rev-parse HEAD)"
}

# THE PASS PATH, and it is the one that matters most here: a barrier that never lifts stops the whole
# autonomous mode, and the first thing anyone does with a barrier that never lifts is skip it.
pmvfix; out="$( cd "$D" && TEST_CMD="sh -c 'exit 0'" sh "$PMV" "$SHA" 2>&1 )"; rc=$?
assert "the merged commit is in HEAD and the tests pass → GREEN, exit 0" 0 "$rc" "$out" 'VERDICT: GREEN'

pmvfix; out="$( cd "$D" && TEST_CMD="sh -c 'exit 1'" sh "$PMV" "$SHA" 2>&1 )"; rc=$?
assert "a failing test command → RED, exit 1, and STOP the run" 1 "$rc" "$out" 'VERDICT: RED.*|STOP the whole run' 'VERDICT: GREEN'

# UNKNOWN is never green. Four ways to not know, one answer, and it must never be mistaken for the
# red above either — "the merge broke a test" and "the barrier could not run" are different repairs.
pmvfix; out="$( cd "$D" && TEST_CMD="sh -c 'exit 0'" sh "$PMV" not-a-real-ref 2>&1 )"; rc=$?
assert "an unresolvable commit → UNKNOWN, exit 2 (never GREEN)" 2 "$rc" "$out" 'could not resolve' 'VERDICT: (GREEN|RED)'

pmvfix; out="$( cd "$D" && PATH="$GITONLY" TEST_CMD="sh -c 'exit 0'" "$SH" "$PMV" 424242 2>&1 )"; rc=$?
assert "a bare PR number with no gh to resolve it → UNKNOWN, exit 2" 2 "$rc" "$out" 'could not resolve .424242.'

pmvfix; out="$( cd "$D" && sh "$PMV" 2>&1 )"; rc=$?
assert "no commit/PR argument at all → UNKNOWN, exit 2" 2 "$rc" "$out" 'no merged commit/PR given'

# The subtlest one: a resolvable commit that is NOT in the tree we are about to test. A green there
# is a true statement about the wrong code — which is worse than no statement.
pmvfix; gitcommit "$D" 'feat: the merge under test'
ORPHAN="$(git -C "$D" rev-parse HEAD)"
git -C "$D" reset --hard "$SHA" >/dev/null 2>&1
out="$( cd "$D" && TEST_CMD="sh -c 'exit 0'" sh "$PMV" "$ORPHAN" 2>&1 )"; rc=$?
assert "the merged commit is NOT in HEAD's history → UNKNOWN, exit 2 (green would be the wrong tree)" 2 "$rc" "$out" 'not in HEAD.s history' 'VERDICT: GREEN'

pmvfix; out="$( cd "$D" && sh "$PMV" "$SHA" 2>&1 )"; rc=$?
assert "no resolvable test command → UNKNOWN, exit 2 (an un-run verification is not a green one)" 2 "$rc" "$out" 'no project test command could be resolved'

# A missing TOOL is UNKNOWN, not RED. Running an absent binary exits non-zero, and reading that as a
# failing test would revert a merge over a broken runner installation.
pmvfix; out="$( cd "$D" && TEST_CMD='pmv-no-such-runner --all' sh "$PMV" "$SHA" 2>&1 )"; rc=$?
assert "the test runner is not on PATH → UNKNOWN, exit 2 (never RED)" 2 "$rc" "$out" 'not on PATH' 'VERDICT: RED'

N=$((N+1)); D="$TMP/pmv-nogit$N"; mkdir -p "$D"
out="$( cd "$D" && TEST_CMD="sh -c 'exit 0'" sh "$PMV" HEAD 2>&1 )"; rc=$?
assert "not inside a git repository → UNKNOWN, exit 2" 2 "$rc" "$out" 'not inside a git repository'

# =================================================================================================
echo
echo "autonomous-merge-report.sh"
# What an autonomous run actually merged, reconstructed from two records it did not author: the gate
# ledger and the git log. 0 = report produced, 2 = the ledger could not be read → NOT produced.
# =================================================================================================

amrfix() {
  N=$((N+1)); D="$TMP/amr$N"; gitrepo "$D"
  printf '# fixture\n' > "$D/README.md"
  gitcommit "$D" 'chore: baseline'
  BASE="$(git -C "$D" rev-parse HEAD)"
  gitcommit "$D" 'feat: cache the widget list (#12)'
  gitcommit "$D" 'fix: retry the export (#14)'
  gitcommit "$D" 'docs: tidy the runbook'
  LED="$D/gate-ledger.md"
  { printf '| when | PR | verdict | why | outcome |\n|---|---|---|---|---|\n'
    printf '| 2026-08-02T09:00Z | 7 | GO | a GO from BEFORE the run window | ok |\n'
    printf '| 2026-08-03T12:05Z | 12 | GO | clean refactor, safe paths only | ok |\n'
    printf '| 2026-08-03T12:20Z | 15 | NO-GO | EX-PAY - billing touched - verbatim-marker-9c3f | ok |\n'
    printf '| 2026-08-03T12:30Z | 99 | GO | armed, no merge yet | ok |\n'
    printf '| 2026-08-03T12:40Z | 16 | MOOT | reviewed after the merge landed | ok |\n'; } > "$LED"
}
amr() { ( cd "$D" && sh "$AMR" "$@" 2>&1 ); }

amrfix; out="$(amr "$LED" "$BASE..HEAD" 2026-08-03T12:00:00Z)"; rc=$?
assert "a ledger crossed with a git range → report, exit 0" 0 "$rc" "$out" 'PR #12 · merged .* · gate GO @ 2026-08-03T12:05Z'
# The disagreements are the valuable part, and this one is the loud one: something landed on main
# with no recorded GO. It is an anomaly for a human, not a conviction — but it must never be quiet.
assert "a merge with NO recorded GO since start is surfaced LOUDLY" 0 "$rc" "$out" 'PR #14.*no gate GO row since start'
assert "a landing with no PR reference at all is surfaced too (it cannot be matched to any verdict)" 0 "$rc" "$out" 'no PR reference in the subject'
assert "a GO with no merge is noted, not counted as a merge" 0 "$rc" "$out" 'PR #99 · GO @'
assert "a GO from BEFORE the run window is outside the report" 0 "$rc" "$out" 'PR #99' 'PR #7 '
assert "a MOOT row is not a merge decision and is ignored" 0 "$rc" "$out" 'Withheld' '#16'

# ── THE ASSERTION THIS SECTION EXISTS FOR ────────────────────────────────────────────────────────
# The withheld reason is the verdict the GATE recorded at the time. Re-deriving it here would be a
# second, weaker guess made hours later by a process with less evidence — and it would quietly
# overwrite the record the whole autonomy argument rests on. It is quoted, character for character.
assert "a withheld reason is printed VERBATIM from the ledger, never re-judged" 0 "$rc" "$out" 'PR #15 · NO-GO @ 2026-08-03T12:20Z · EX-PAY - billing touched - verbatim-marker-9c3f'
assert "and the report says every line traces to a record, not to memory" 0 "$rc" "$out" 'nothing is reconstructed from'

# NEVER FABRICATE. A guessed report is worse than none: "nothing merged autonomously" and "we do not
# know what merged" look identical on the page and could not be further apart.
amrfix; out="$(amr "$D/no-such-ledger.md" "$BASE..HEAD" 2026-08-03T12:00:00Z)"; rc=$?
assert "an unreadable gate ledger → UNKNOWN, exit 2, and NO report is produced" 2 "$rc" "$out" 'cannot reconstruct the run' 'Autonomously merged|Withheld'

amrfix; out="$(amr "$LED" "$BASE..HEAD")"; rc=$?
assert "missing arguments → UNKNOWN, exit 2" 2 "$rc" "$out" 'need <gate-ledger>'

# The asymmetry is deliberate: the LEDGER is load-bearing, the git log is corroboration. Losing the
# corroboration degrades the report and must SAY so — it must never present GO rows as merges.
amrfix; out="$(amr "$LED" "no-such-ref..HEAD" 2026-08-03T12:00:00Z)"; rc=$?
assert "an unreadable git range degrades to a ledger-only view, exit 0, labelled un-corroborated" 0 "$rc" "$out" 'NOT corroborated' '### Autonomously merged'
assert "and every GO in that view is marked as an unverified merge" 0 "$rc" "$out" 'merge unverified'

# =================================================================================================
echo
echo "handoff-lint.sh"
# The hygiene the file-based handoff rests on. 0 = clean, 1 = a violation, 2 = could not check.
# =================================================================================================

hlfix() {   # a clean handoff repo: temp/ gitignored, a mailbox file present but untracked
  N=$((N+1)); D="$TMP/hl$N"; gitrepo "$D"
  printf 'temp/\n' > "$D/.gitignore"
  mkdir -p "$D/temp/output"
  printf 'the spec the pointer points at\n' > "$D/temp/output/spec.md"
  printf '# fixture\n' > "$D/README.md"
  gitcommit "$D" 'chore: baseline'
}

hlfix; out="$(sh "$HANDOFF" "$D" 2>&1)"; rc=$?
assert "temp/ gitignored and nothing tracked under it → OK, exit 0" 0 "$rc" "$out" 'VERDICT: OK'

# THE PATTERN THIS REPO ITSELF USES. Its .gitignore says `temp/**`, which `git check-ignore temp`
# does NOT match — only `git check-ignore temp/` does. The lint asks both questions for exactly this
# reason, and if someone ever "simplifies" that to one, the suite's own repo fails its own lint.
hlfix; printf 'temp/**\n' > "$D/.gitignore"; gitcommit "$D" 'chore: ignore temp'
out="$(sh "$HANDOFF" "$D" 2>&1)"; rc=$?
assert "a 'temp/**' ignore rule counts as gitignored (this repo's own pattern) → exit 0" 0 "$rc" "$out" 'temp/ is gitignored'

# The failure this whole design guards against, and the reason it needs a script: a force-added file
# under temp/ looks exactly like any other tracked file to a reviewer.
hlfix; git -C "$D" add -f temp/output/spec.md >/dev/null 2>&1
out="$(sh "$HANDOFF" "$D" 2>&1)"; rc=$?
# The `x` PREFIX is asserted, not just the sentence. `bad()` prints `x` and owns the exit code;
# `warn()` prints `!` and does not. Without the prefix this case still passes when the check is
# downgraded to an advisory — because of the defect immediately below, which keeps the exit at 1 for
# an unrelated reason. Asserting the sentence would have been a test that cannot fail.
assert "a TRACKED file under temp/ → VIOLATION, exit 1, and it is a HARD failure (x, not !)" 1 "$rc" "$out" '  x tracked file\(s\) under temp/: temp/output/spec.md' 'VERDICT: OK'

# ── KNOWN DEFECT (NEW — not in the 2026-08-03 audit; found by writing this test) ──────────────────
# handoff-lint.sh's own comment says `git check-ignore` "evaluates the ignore rules against the
# pathname whether or not the directory exists yet — so this is a statement about the RULE, not about
# today's contents." IT IS NOT. check-ignore consults the INDEX unless you pass `--no-index`, so the
# instant a file under temp/ is TRACKED — which is violation #2, the precise thing this script exists
# to catch — check-ignore reports temp/ as not ignored, and the lint prints a SECOND, FALSE violation
# telling you to add a rule that is already sitting in .gitignore.
# Two costs, and the second is the reason this line is here:
#   · the repair it prints is wrong. Following it changes nothing, and the real violation is now one
#     of two complaints instead of the only one.
#   · the two checks stop being independent, so the EXIT CODE can no longer tell them apart. A
#     regression that turns the tracked-file check into an advisory still exits 1 — through the false
#     violation. That mutation passed this whole suite until the assertion above was tightened.
# Fix: `git check-ignore --no-index -q temp || git check-ignore --no-index -q temp/`. Then flip this
# case to expect `temp/ is gitignored` alongside the tracked-file violation.
assert_xfail "KNOWN DEFECT (new): a tracked file also flips the ignore RULE check to 'NOT gitignored'" 1 "$rc" "$out" 'temp/ is NOT gitignored'

hlfix; rm -f "$D/.gitignore"; gitcommit "$D" 'chore: drop the ignore rule'
out="$(sh "$HANDOFF" "$D" 2>&1)"; rc=$?
assert "temp/ not gitignored → VIOLATION, exit 1 (the mailbox must be scratch)" 1 "$rc" "$out" 'temp/ is NOT gitignored'

N=$((N+1)); D="$TMP/hl-nogit$N"; mkdir -p "$D"
out="$(sh "$HANDOFF" "$D" 2>&1)"; rc=$?
assert "not a git repository → could-not-check, exit 2 (held, never waved through)" 2 "$rc" "$out" 'not a git repository' 'VERDICT'

out="$(sh "$HANDOFF" "$TMP/no-such-root" 2>&1)"; rc=$?
assert "a repo root that does not exist → could-not-check, exit 2" 2 "$rc" "$out" 'cannot cd'

# ── --message mode ───────────────────────────────────────────────────────────────────────────────
# EVERY SECRET-SHAPED FIXTURE BELOW IS ASSEMBLED AT RUN TIME. A test that carries the literal it
# tests is a literal in the repo, and the suite's own hook already blocked a commit over exactly that
# (field report 2026-08-03). The source of this file never holds a whole token shape.
msgnew() {  # $1 = basename; body on stdin
  N=$((N+1)); MD="$TMP/msg$N"; mkdir -p "$MD"; MSG="$MD/$1"; cat > "$MSG"
}
GOODNAME='2026-08-03T09-15-00Z__aqua-42__req.md'

msgnew "$GOODNAME" <<'EOF'
From: wai-team@repo-a
To: wai-implementation@repo-b
Correlation-Id: aqua-42
Kind: request
Pointer: temp/output/2026-08-03T09-15-00Z__aqua-42__req.md

Please pick up the spec at the pointer. Nothing is inlined here.
EOF
out="$(sh "$HANDOFF" --message "$MSG" 2>&1)"; rc=$?
assert "a well-formed pointer envelope → OK, exit 0" 0 "$rc" "$out" 'VERDICT: OK'
assert "  · the filename schema is what makes a message correlatable at all" 0 "$rc" "$out" 'filename matches the envelope schema'
assert "  · and the pointer resolves into a temp/ mailbox" 0 "$rc" "$out" 'pointer references a temp/ mailbox'

# Known SHAPES hard-fail: high precision, and if it is here it should not be.
msgnew "$GOODNAME" <<'EOF'
From: a
To: b
Correlation-Id: aqua-42
Kind: request
Pointer: temp/output/x.md
EOF
printf 'Use %s%s to reach the bucket.\n' 'AKIA' 'IOSFODNN7EXAMPLE' >> "$MSG"
out="$(sh "$HANDOFF" --message "$MSG" 2>&1)"; rc=$?
assert "an AKIA-shaped key inlined → VIOLATION, exit 1" 1 "$rc" "$out" 'known-shape secret is inlined' 'VERDICT: OK'

msgnew "$GOODNAME" <<'EOF'
From: a
To: b
Correlation-Id: aqua-42
Kind: request
Pointer: temp/output/x.md
EOF
printf 'Token: %s%s\n' 'sk-' 'abcdefghijklmnopqrstuvwx' >> "$MSG"
out="$(sh "$HANDOFF" --message "$MSG" 2>&1)"; rc=$?
assert "an sk--shaped token inlined → VIOLATION, exit 1" 1 "$rc" "$out" 'known-shape secret is inlined'

# The private-key branch is the one the pattern's own comment calls out: its ERE starts with a dash,
# and without grep's `-e` the whole secret check would silently never run.
msgnew "$GOODNAME" <<'EOF'
From: a
To: b
Correlation-Id: aqua-42
Kind: request
Pointer: temp/output/x.md
EOF
printf '%s%s %s-----\n' '-----BEGIN' ' RSA' 'PRIVATE KEY' >> "$MSG"
out="$(sh "$HANDOFF" --message "$MSG" 2>&1)"; rc=$?
assert "a private-key header inlined → VIOLATION, exit 1 (the leading-dash pattern still runs)" 1 "$rc" "$out" 'known-shape secret is inlined'

# ── THE ASSERTION THIS SECTION EXISTS FOR ────────────────────────────────────────────────────────
# Generic high entropy is a WARNING and nothing more. An entropy gate that fails hard cries wolf on
# the base64 hash a correlation pointer legitimately carries — and a lint that cries wolf is a lint
# that gets switched off. Fix leaks with precision, not with strictness. (V1-5.)
msgnew "$GOODNAME" <<'EOF'
From: a
To: b
Correlation-Id: aqua-42
Kind: request
Pointer: temp/output/x.md
EOF
printf 'Correlation hash: %s%s\n' '9c3f81a4b27e5d0619fa73c8e42b90d5' '17ae6b3c94f80d25e7a1' >> "$MSG"
out="$(sh "$HANDOFF" --message "$MSG" 2>&1)"; rc=$?
assert "generic high-entropy is a WARNING ONLY → still exit 0" 0 "$rc" "$out" '! a long high-entropy token' 'VERDICT: VIOLATION'

# Pointer, not payload — the boundary that keeps a contract-domain artifact from crossing a repo
# boundary unreviewed, in a file nobody reviews.
msgnew "$GOODNAME" <<'EOF'
From: a
To: b
Correlation-Id: aqua-42
Kind: request
Pointer: temp/output/x.md

```yaml
openapi: 3.0.3
```
EOF
out="$(sh "$HANDOFF" --message "$MSG" 2>&1)"; rc=$?
assert "a fenced code block is an INLINED PAYLOAD → VIOLATION, exit 1" 1 "$rc" "$out" 'inlined payload, not a pointer'

msgnew 'handoff-notes.md' <<'EOF'
From: a
To: b
Correlation-Id: aqua-42
Kind: request
Pointer: temp/output/x.md
EOF
out="$(sh "$HANDOFF" --message "$MSG" 2>&1)"; rc=$?
assert "a filename off the envelope schema → VIOLATION, exit 1 (an uncorrelatable message is a lost one)" 1 "$rc" "$out" 'off the envelope schema'

msgnew "$GOODNAME" <<'EOF'
From: a
Kind: request
Pointer: temp/output/x.md
EOF
out="$(sh "$HANDOFF" --message "$MSG" 2>&1)"; rc=$?
assert "a missing required header → VIOLATION, exit 1, and it names the header" 1 "$rc" "$out" 'required header missing or empty: To'

out="$(sh "$HANDOFF" --message "$TMP/no-such-message.md" 2>&1)"; rc=$?
assert "an unreadable message → could-not-check, exit 2" 2 "$rc" "$out" 'cannot read message'

out="$(sh "$HANDOFF" --message 2>&1)"; rc=$?
assert "--message with no file → could-not-check, exit 2" 2 "$rc" "$out" 'needs a file'

# ── KNOWN DEFECT (audit 2026-08-03) ─────────────────────────────────────────────────────────
# `NLINES="$(grep -c . "$MSG" 2>/dev/null || echo 0)"`. On a message with no non-empty lines, `grep
# -c .` PRINTS "0" and EXITS 1, so the `|| echo 0` fires as well and NLINES becomes two lines. The
# `[ "$NLINES" -gt 60 ]` that follows is then handed a non-number and the shell reports it — dash
# says "Illegal number", bash says "integer expression expected", both to stderr, both naming the
# line. The verdict is right only by accident (an empty envelope fails five header checks anyway),
# which is precisely why nobody noticed. Asserted as it behaves TODAY. The fix is one line:
#   NLINES="$(grep -c . "$MSG" 2>/dev/null)"; NLINES="${NLINES:-0}"
# then flip this case to assert the error is GONE.
msgnew "$GOODNAME" </dev/null
out="$(sh "$HANDOFF" --message "$MSG" 2>&1)"; rc=$?
assert_xfail "KNOWN DEFECT: an EMPTY envelope leaks a shell error from the length check" 1 "$rc" "$out" '\[: '
assert_xfail "KNOWN DEFECT: …and the length check silently never ran (no length verdict either way)" 1 "$rc" "$out" 'VERDICT: VIOLATION' 'the envelope is [0-9]+ non-empty lines'

echo
# The pinned count stands NEXT to passed/failed, never inside them — six pinned defects once
# counted as `ok`, and "220 cases, all green" read as health. CI sums cases as $1+$5 of this line.
if [ "$XFAIL" -gt 0 ]; then
  printf '%s passed, %s failed, %s known defects pinned (XFAIL — a pin that stops reproducing FAILS)\n' "$PASS" "$FAIL" "$XFAIL"
else
  printf '%s passed, %s failed\n' "$PASS" "$FAIL"
fi
[ "$FAIL" -eq 0 ]
