#!/usr/bin/env sh
# contract-lint.sh — the suite's script↔prompt contracts, as an exit code.
#
# ADR-0002 moved the mechanics into scripts and left the judgment in the prompts. That split created
# a JOINT, and a joint drifts: a script gains a third exit code while a prompt documents two; a skill
# is renamed and a documented path stops resolving. A stale prompt does not crash — it QUIETLY
# INSTRUCTS THE WRONG THING, and the good run and the bad run produce identical output.
# Why: docs/rationale/contract-lint.md § Fifteen findings, one absent operation
#
# THREE CHECKS, AND DELIBERATELY ONLY THREE. ADR-0002 is explicit that the fix for a wolf-crying
# check is more PRECISION, never more STRICTNESS — a lint that cries wolf gets switched off, and
# then it is worse than no lint, because it is still right about what it catches and nobody reads
# it. So: three checks that are mechanically decidable, and nothing that needs a judgment call.
#
#   1. Every script has a caller.        A script no prompt names is dead weight — or worse, a
#                                        mechanism someone believes is running.
#   2. Every documented path resolves.   "Run scripts/foo.sh" is a lie if it does not exist from
#                                        where the prompt says to run it.
#   3. Every exit code is documented.    An undocumented code is a coin flip: the model invents a
#                                        meaning for it, and fail-closed becomes fail-open.
#
#   exit 0  the two sides still describe each other
#   exit 1  a check failed — the reasons are printed
#   exit 2  the tree could not be read (fail-closed: "I could not look" is not "it is fine")
#
# Usage: sh contract-lint.sh [repo-root]         (default: .)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX pattern semantics required

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "contract-lint: cannot cd to '$ROOT'" >&2; exit 2; }
[ -d ".claude/skills" ] || { echo "contract-lint: no .claude/skills under '$ROOT' — nothing to check." >&2; exit 2; }

FAIL=0
bad()  { FAIL=1; printf '  ✗ %s\n' "$1"; }
ok()   {          printf '  ✓ %s\n' "$1"; }
warn() {          printf '  ⚠ %s\n' "$1"; }   # advisory — never changes the exit code
hint() {          printf '      %s\n' "$1"; }

# THE TWO SIDES OF THE CONTRACT.
# Scripts: `.claude/skills/*/scripts/*.sh`. `tests/` is excluded because a test harness is not a
# mechanism the prompts invoke — requiring a prompt to name `run.sh` would be a check nobody can
# obey. `templates/` is excluded because a template is COPIED into a target repo: its paths resolve
# THERE, not here, and linting them against this tree is the same category error as resolving
# another repo's catalog IDs against ours.
SCRIPTS="$(find .claude/skills -type f -path '.claude/skills/*/scripts/*.sh' \
             ! -path '*/tests/*' ! -path '*/templates/*' 2>/dev/null | sort || true)"
# Prompts: every `.md` a skill ships. Test fixtures are data, not prompts.
PROMPTS="$(find .claude/skills -type f -name '*.md' ! -path '*/tests/*' 2>/dev/null | sort || true)"
# For path resolution only — a template's paths belong to the repo it is copied into.
RUNNABLE="$(printf '%s\n' "$PROMPTS" | grep -v '/templates/' || true)"

[ -n "$SCRIPTS" ] || { echo "contract-lint: no scripts under .claude/skills/*/scripts/ — is the suite installed?" >&2; exit 2; }
[ -n "$PROMPTS" ] || { echo "contract-lint: no skill prompts under .claude/skills/ — is the suite installed?" >&2; exit 2; }

N_S="$(printf '%s\n' "$SCRIPTS" | grep -c . || true)"
N_P="$(printf '%s\n' "$PROMPTS" | grep -c . || true)"

# Every script basename, space-separated on one line. Check 2 uses it to tell a SUITE script from a
# path that belongs to the target repo; check 3 uses it to spot an ambiguous attribution.
BNS=""
for s in $SCRIPTS; do BNS="$BNS ${s##*/}"; done

echo "contract-lint: $ROOT"
echo "  $N_S scripts · $N_P prompt files"

# --- 1. Every script has a caller ---------------------------------------------------------------
# A script nobody invokes is not neutral. It reads as a live mechanism to everyone who finds it, it
# is maintained as one, and its existence is quietly cited as coverage — while nothing runs it. The
# check is deliberately weak on purpose: a BASENAME mentioned ANYWHERE in ANY prompt counts. That
# cannot tell a real invocation from a passing mention, and it does not try to; it catches the one
# thing that is unambiguous — nobody mentions this at all.
ORPHAN=""
for s in $SCRIPTS; do
  bn="${s##*/}"
  # shellcheck disable=SC2086  # the file list must word-split
  grep -qF -- "$bn" $PROMPTS 2>/dev/null || ORPHAN="$ORPHAN $bn"
done
if [ -z "$ORPHAN" ]; then
  ok "every script is named by at least one prompt ($N_S/$N_S)"
else
  bad "script(s) no prompt names:$ORPHAN — nothing invokes them; delete, or wire them into the skill that should"
fi

# --- 2. Every script path a prompt names resolves -------------------------------------------------
# Resolved from where the PROMPT says to run it, not from the repo root: "run scripts/foo.sh from
# this skill's directory" is a different claim than "scripts/foo.sh exists".
# Why: docs/rationale/contract-lint.md § Every script path a prompt names must resolve
UNRESOLVED=""; ADVISORY=""; N_SUITE=0; N_OTHER=0
REF_RE='([A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.sh'
for f in $RUNNABLE; do
  rel="${f#.claude/skills/}"
  sdir=".claude/skills/${rel%%/*}"
  for ref in $(grep -ohE "$REF_RE" "$f" 2>/dev/null | sort -u); do
    rbn="${ref##*/}"
    case " $BNS " in
      *" $rbn "*) N_SUITE=$((N_SUITE + 1)) ;;       # one of ours — a resolvable claim, so check it
      *) N_OTHER=$((N_OTHER + 1))                   # not ours — cannot be judged, only reported
         if [ ! -f "$ref" ] && [ ! -f "$sdir/$ref" ]; then
           ADVISORY="$ADVISORY
$f names '$ref' — no such file here"
         fi
         continue ;;
    esac
    [ -f "$ref" ] && continue                       # resolves from the repo root
    [ -f "$sdir/$ref" ] && continue                 # resolves from the referencing skill
    # Name the base it DOES resolve from. A finding that names the repair is a finding people act on.
    where="nowhere"
    [ -f ".claude/skills/$ref" ] && where="only from .claude/skills/ — prefix the path with '.claude/skills/'"
    [ -f "$sdir/scripts/$ref" ] && where="only from $sdir/scripts/ — that is script-relative, and a prompt is not read from there"
    UNRESOLVED="$UNRESOLVED
$f names '$ref' — resolves $where"
  done
done
if [ -z "$UNRESOLVED" ]; then
  ok "every documented path to a suite script resolves ($N_SUITE/$N_SUITE)"
else
  bad "documented suite-script path(s) that do not resolve from the repo root or the referencing skill:"
  printf '%s\n' "$UNRESOLVED" | grep . | while IFS= read -r line; do hint "$line"; done
  hint "→ an agent reading this runs the path as written, from the repo root. Write it so it resolves."
fi
if [ -n "$ADVISORY" ]; then
  warn "$N_OTHER path(s) named do not belong to this suite; these do not exist here — ADVISORY, not failed:"
  printf '%s\n' "$ADVISORY" | grep . | while IFS= read -r line; do hint "$line"; done
  hint "  a skill legitimately tells a TARGET repo to create files. If one of these is a suite"
  hint "  script, it is misspelled — that is the only reading this check cannot rule out."
fi

# --- 3. Every exit code is documented where the script is invoked ---------------------------------
# An undocumented code is a coin flip: the model invents a meaning, and fail-closed becomes
# fail-open. Evidence may come from any prompt that names the script, or the script's own header.
# Why: docs/rationale/contract-lint.md § Every exit code is documented where the script is invoked
codes_of() {
  {
    grep -E '^[[:space:]]*#[[:space:]]*exit[[:space:]]+[0-9]+' "$1" 2>/dev/null
    sed -e 's/^[[:space:]]*#.*$//' -e 's/"[^"]*"//g' -e "s/'[^']*'//g" -e 's/[[:space:]]#.*$//' "$1" 2>/dev/null \
      | grep -oE '(^|[;&|{(]|[[:space:]])exit[[:space:]]+[0-9]+'
  } | grep -oE 'exit[[:space:]]+[0-9]+' | grep -oE '[0-9]+' | sort -u
}

# Is a code documented in any prompt that names the script? (basename, code, same markdown block.)
# Block-scoped on purpose: a number written about one script in a block that names two counts for
# both — reported as a ⚠ thinness count, never as a pass that hides.
# Why: docs/rationale/contract-lint.md § How a code counts as documented
documented() {
  # $1 = script basename · $2 = code · $3 = file list (word-splitting)
  _ev="[Ee]xit[ \`*_]*$2|[Ee]xit[ \`*_]*(≠|!=|<>)[ \`*_]*0|non-?zero"
  case "$2" in
    1) _ev="$_ev|NO-?GO" ;;
    2) _ev="$_ev|UNKNOWN" ;;
  esac
  # shellcheck disable=SC2086  # the file list must word-split
  awk -v bn="$1" -v ev="$_ev" -v boldev="[*][*]$2[*][*]" -v allbn="$BNS" '
    function flush(   i) {
      if (index(blk, bn) > 0 && (blk ~ ev || (blk ~ /[Ee]xit/ && blk ~ boldev))) {
        found = 1
        for (i = 1; i <= n; i++)
          if (names[i] != bn && index(blk, names[i]) > 0) { ambig = 1; break }
      }
      blk = ""
    }
    BEGIN { found = 0; ambig = 0; n = split(allbn, names, " ") }
    FNR == 1                                     { flush() }
    /^#+ / || /^[0-9]+[a-z]?\. / || /^[-*] /     { flush() }
                                                 { blk = blk "\n" $0 }
    END                                          { flush(); print found " " ambig }
  ' $3 2>/dev/null
}

UNDOC=""; OFFCONV=""; SILENT=""; AMBIG=0; N_CODE=0
for s in $SCRIPTS; do
  bn="${s##*/}"
  # shellcheck disable=SC2086  # the file list must word-split
  MENTIONS="$(grep -lF -- "$bn" $PROMPTS 2>/dev/null | tr '\n' ' ' || true)"
  CODES="$(codes_of "$s")"
  [ -n "$CODES" ] || { SILENT="$SILENT $bn"; continue; }
  for c in $CODES; do
    [ "$c" = 0 ] && continue
    N_CODE=$((N_CODE + 1))
    # The suite's convention is 0 GO · 1 NO-GO · 2 UNKNOWN (ADR-0002). A fourth code is not a
    # richer contract, it is one every caller's `case` silently drops on the floor.
    case "$c" in
      1|2) ;;
      *) OFFCONV="$OFFCONV $bn:$c" ;;
    esac
    if [ -z "$MENTIONS" ]; then
      UNDOC="$UNDOC $bn:$c"; continue
    fi
    RES="$(documented "$bn" "$c" "$MENTIONS")"
    case "$RES" in
      "1 1") AMBIG=$((AMBIG + 1)) ;;
      "1 0") ;;
      *)     UNDOC="$UNDOC $bn:$c" ;;
    esac
  done
done
if [ -z "$UNDOC" ]; then
  ok "every non-zero exit code ($N_CODE) is documented in a prompt that names its script"
else
  bad "exit code(s) a script can return that NO prompt naming it documents:$UNDOC"
  hint "→ the model meets an undocumented code and invents a meaning for it. Document it where the"
  hint "  script is invoked, in the form the suite already uses: \`exit 2\` **UNKNOWN** → …"
fi
if [ -n "$OFFCONV" ]; then
  bad "exit code(s) outside the suite's 0/1/2 convention:$OFFCONV"
  hint "→ ADR-0002 fixes the contract at 0 GO · 1 NO-GO · 2 UNKNOWN. A caller that switches on"
  hint "  those three drops anything else silently — which reads as success. Fold it into 1 or 2."
fi
[ -z "$SILENT" ] || warn "no exit contract this check can read (all exits are via a variable, and no \`#   exit N\` header):$SILENT — their codes are UNCHECKED"
[ "$AMBIG" -eq 0 ] || warn "$AMBIG of $N_CODE codes were confirmed in a block that ALSO names another script — there the number may be documenting the other one. Counted as covered; read as thin."

# --- What a green run here does NOT mean --------------------------------------------------------
# ADR-0002: a green check that implies coverage it does not have is worse than a red one. Every line
# below is a hole this script structurally cannot close, and each is a real failure it would miss.
echo
echo "  NOT CHECKED — a green run above does not mean any of this:"
echo "  · ARGUMENTS — the big one. Whether a documented invocation's flags and operands are"
echo "    ACCEPTED by the script is NOT verified; that needs RUNNING it, and this script only reads."
echo "    \`sh foo.sh --json\` passes here even if foo.sh has no --json and dies on it. SO: A GREEN"
echo "    RUN DOES NOT MEAN EVERY DOCUMENTED COMMAND WORKS. It means every one of them points at a"
echo "    file that exists and returns codes the prompt has heard of."
echo "  · SEMANTICS. Whether the prompt's description of what a code MEANS matches what the script"
echo "    does on that path. Only the presence of the number is checked, never its meaning."
echo "  · ATTRIBUTION. Exit-code evidence is scoped to the markdown block. Where a block names two"
echo "    scripts, a number written about one of them counts for both (see the ⚠ count, if any)."
echo "  · Whether a mention is an INVOCATION. Check 1 accepts any mention of a basename, so a"
echo "    script named only in a sentence about history counts as called."
echo "  · Codes behind a variable (\`exit \"\$RC\"\`) unless the script's own header declares them."
echo "  · Non-.md callers — a workflow, a hook or another script that invokes one of these."

echo
if [ "$FAIL" -eq 0 ]; then
  echo "VERDICT: OK — scripts and prompts still describe each other."
else
  echo "VERDICT: FAILED — a script and the prompt that invokes it disagree; fix the above."
fi
exit "$FAIL"
