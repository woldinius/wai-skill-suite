#!/usr/bin/env sh
# doctor.sh — does this repo's STATE still match what the installed suite EXPECTS?
#
# install.sh updates the SKILLS. It cannot update what they GENERATED (the catalog, ci.yml, the gate
# config) or the contract they assume (merge-gate.conf present AND non-empty, the shared classifier
# next to this script, the learning ledger's path). So an upstream update can change the contract and
# the repo silently falls out of step — the merge gate returns UNKNOWN on every PR, learning mode
# switches itself off — and NOTHING reports it, because a missing file looks exactly like a repo
# nobody has touched lately. install.sh used to print a sentence about this; a sentence is not a
# mechanism. This is the mechanism, and it runs at UPDATE time (when the contract changes), not only
# at run time (too late).
#
# PHASE A — PRESENCE + user-state. It reports EXPECTED-but-MISSING artifacts, artifacts that are
# present but CONFIGURED BLIND (a conf whose keys are all empty checks almost nothing), and legacy
# state. It does NOT yet detect STALENESS (an artifact generated from an OLDER template — e.g. a
# ci.yml without the image-scan CVE layer). That needs a per-artifact provenance stamp, which is
# a later phase; the version stamp this reads is the foundation for it.
#
# ── THREE STATES, NOT TWO — AND THIS SCRIPT SHIPPED WITH THE FOLD IT EXISTS TO REPORT ──────────
#
# merge-gate.sh's own header calls the NO-GO/UNKNOWN distinction load-bearing, and names why:
#
#   NO-GO   is a fact about the PR.        It failed a check.
#   UNKNOWN is a bug report about the GATE. It could not check.
#
# Fold them and you throw away the only signal that says the tool needs fixing. This script shipped
# with exactly that fold, one level up: it returned 2 for "I found drift in your repo" AND 2 for "I
# could not even cd into it". A DRIFT DETECTOR THAT CANNOT TELL "THE REPO IS BROKEN" FROM "I AM
# BROKEN" IS THE SAME BUG IT WAS BUILT TO CATCH — and it is worse here than in the gate, because
# nobody reads a doctor that misreports which of its own states it is in. So, in this suite's
# convention (a defined negative is 1; unverifiable is 2):
#
#   exit 0  no drift that disables a feature — clean, or only soft advisories (·)
#   exit 1  DRIFT (✗) — a defined negative: a feature is silently off. A fact about the REPO. Act.
#   exit 2  UNKNOWN (?) — a check could not be run at all. A fact about the DOCTOR. Fail closed.
#
# If both occur the exit code is 1 and BOTH summary lines print. Reporting a CONFIRMED drift as "I
# could not check" would re-commit the very misreport being removed here; the unverified items keep
# their own `?` lines in the body regardless, so no signal is lost — only the headline is chosen.
#
# Usage: sh doctor.sh [repo-root]        (default: .)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

ROOT="${1:-.}"
# Cannot enter the repo ⇒ nothing below was checked. That is state 2, and it is the ONE case where
# saying "no drift" would be a lie of omission rather than a finding.
cd "$ROOT" 2>/dev/null || { echo "doctor: cannot cd to '$ROOT'" >&2; exit 2; }

DRIFT=0
UNVERIFIED=0
drift()   { DRIFT=1;      printf '  ✗ %s\n' "$1"; }   # exit 1 — a feature is silently off
unknown() { UNVERIFIED=1; printf '  ? %s\n' "$1"; }   # exit 2 — doctor could not check this at all
note()    {               printf '  · %s\n' "$1"; }   # advisory — never changes the exit code
ok()      {               printf '  ✓ %s\n' "$1"; }

# A repo-local conf is PARSED, never sourced. `. conf` would execute a file that lives in the repo
# being diagnosed, on a machine that has git credentials and a webhook secret in its environment —
# and doctor is run by install.sh, unattended, on a tree the human may not have read yet. Same rule
# and same one-liner as coordination-lint.sh and excluded-domains.sh: grep the one key, strip the
# quotes, take the first hit. A `# COMMENTED_KEY="x"` example line cannot match, because of the ^.
conf_val() { sed -n "s/^$1=//p" "$2" 2>/dev/null | tr -d '"' | head -1; }

echo "doctor: $ROOT"

# Suite version — the provenance foundation. Phase B compares an artifact's stamp against this.
VER=".claude/.wai-suite-version"
if [ -f "$VER" ]; then ok "installed suite version: $(head -1 "$VER" 2>/dev/null)"
else note "no $VER — re-run install.sh to stamp the suite version (staleness checks will need it)"; fi

CATALOG="docs/architecture/quality-attributes.md"
CONF="docs/architecture/merge-gate.conf"
COORD="docs/architecture/coordination.conf"
LEDGER="docs/architecture/gate-ledger.md"   # merge-gate.sh's default; $MERGE_GATE_LEDGER overrides it

if [ -f "$CATALOG" ]; then
  # The catalog is the proof this repo WAS set up. Everything below is drift only BECAUSE it was.
  # merge-gate.conf was introduced after the suite's first repos existed — so a repo set up before
  # it has a catalog and no conf, and the gate then returns UNKNOWN on every PR, which reads exactly
  # like "nobody has opened a PR lately". This is the incident that filed this check.
  if [ -f "$CONF" ]; then
    ok "merge gate is configured (catalog + merge-gate.conf)"
    # THE GATE HAS A DENOMINATOR, AND AN EMPTY ONE IS NOT A CLEAN RECORD. merge-gate.sh appends every
    # verdict it emits to an append-only ledger, precisely so "the model checked" can be audited. A
    # set-up repo with no ledger file has never had a single verdict written — which is indis-
    # tinguishable, from the outside, from a repo whose gate has been GO-ing along quietly. ADVISORY,
    # never drift: a repo may legitimately not have opened a PR yet, and crying wolf on day one is how
    # a checker teaches people to skim it.
    [ -f "$LEDGER" ] || note "no $LEDGER — this repo has never recorded a gate verdict. If PRs HAVE been reviewed here, they were reviewed without running the gate (that is itself a finding, empirical-test-plan §0)."
  else
    drift "merge-gate.conf is MISSING though the catalog exists → the merge gate returns UNKNOWN on EVERY PR (silently non-functional). Run wai-init to write it."
  fi
  # A set-up repo with no CI at all: the gate then reports 'no CI checks', which is not green. This
  # is a NOTE, not drift — a repo may legitimately have no CI yet (this very suite repo did for a
  # while); flagging it as a feature-off would cry wolf.
  if ! ls .github/workflows/*.yml >/dev/null 2>&1; then
    note "no .github/workflows/*.yml — the merge gate will report 'no CI checks' (not green). If this repo is meant to have CI, run wai-cicd."
  fi
else
  note "no quality catalog yet — run wai-init to set the suite up here (nothing can drift until it is)."
fi

# ── A PRESENT CONF IS NOT A CONFIGURED CONF ─────────────────────────────────────────────────────
# The template ships CONTRACT_PATHS, MIGRATION_PATHS and ERASURE_PATHS all EMPTY — correctly, since
# only the repo knows its own risky paths — and the classifier SKIPS any test whose key is empty
# (`[ -n "$CONTRACT_PATHS" ] && …`). Both halves are right on their own. Together they make a third
# state nobody named: a conf that EXISTS, passes every presence check in this script and in the
# gate, and checks almost nothing. The presence test above says "configured"; it can only see the
# file.
#
# CONTRACT_PATHS empty is DRIFT. It is the key that decides "is this billing / auth / API-surface,
# i.e. the human's alone?" — empty means NO path is contract-domain, so a billing PR classifies
# CLEAN and is eligible to be agent-merged. The hardcoded GUARDRAIL floor in the classifier still
# protects the suite's OWN files, which is exactly what makes this invisible: the gate keeps saying
# sensible things about `.claude/**` while the repo's real contract surface is unguarded.
#
# ERASURE_PATHS empty is an ADVISORY, and the difference is a real one, not a softening: the
# classifier's EX-GDPR check greps the WHOLE diff for erasure statements whether or not the key is
# set, so an ad-hoc `DELETE FROM users` is still caught by the backstop. Empty here degrades a
# primary anchor to a grep; empty CONTRACT_PATHS degrades a check to nothing.
#
# MIGRATION_PATHS is deliberately NOT judged. Empty is the common, honest answer (no database), and
# the destructive-DDL escalation it gates is scoped to migration files by construction.
if [ -f "$CONF" ]; then
  if [ ! -r "$CONF" ]; then
    unknown "$CONF exists but cannot be read — cannot tell whether the gate's path globs are configured or empty."
  else
    CP="$(conf_val CONTRACT_PATHS "$CONF")"
    EP="$(conf_val ERASURE_PATHS "$CONF")"
    if [ -n "$CP" ]; then
      ok "CONTRACT_PATHS is defined in merge-gate.conf (the gate has a contract surface to test against)"
    else
      drift "CONTRACT_PATHS is empty (or absent) in $CONF → the classifier SKIPS the contract-domain test entirely, so a billing/auth/API PR is classified CLEAN and stays agent-mergeable. The conf exists, so every presence check passes while the check itself does nothing. Name this repo's contract paths (wai-init proposes them)."
    fi
    [ -n "$EP" ] || note "ERASURE_PATHS is empty in $CONF — the EX-GDPR check falls back to its whole-diff erasure grep alone (a backstop, not an anchor). Name the erasure module if this repo has one."
  fi
fi

# ── The shared domain classifier — ITS PRESENCE BECAME LOAD-BEARING, AND NOTHING WATCHED IT ─────
# merge-gate.sh no longer decides "is this an excluded domain?" itself. Since the §5 refactor it
# CALLS `../../wai/scripts/excluded-domains.sh` — one definition for the everyday gate,
# pr-review and wai-team's drain, so three copies cannot disagree about what is human-only.
# The cost of that single source is a single point of failure: the gate FAILS CLOSED when the file
# is not there, so a missing classifier is UNKNOWN on EVERY PR, forever.
#
# And an UNKNOWN gate emits no merges — which is precisely what a healthy gate looks like on a quiet
# week. This is that same incident with a new missing file in it, so it gets the same verdict: DRIFT,
# not an advisory.
#
# LOOKED UP RELATIVE TO THE REPO, NEVER TO $0. doctor is routinely run from a suite CHECKOUT against
# a foreign target — install.sh's last line does exactly that. Resolving the classifier next to THIS
# script would find the checkout's own copy and pronounce the target healthy. The only question that
# matters is what the TARGET's merge-gate.sh will find when it runs there, and it resolves the path
# from its own location inside the target: .claude/skills/wai/scripts/excluded-domains.sh.
GATE_SH=".claude/skills/wai-pr-review/scripts/merge-gate.sh"
EXCL_SH=".claude/skills/wai/scripts/excluded-domains.sh"
if [ -f "$GATE_SH" ]; then
  if [ -f "$EXCL_SH" ]; then
    ok "the shared domain classifier is installed where merge-gate.sh looks for it ($EXCL_SH)"
  else
    drift "$EXCL_SH is MISSING though $GATE_SH is installed → the gate cannot classify excluded domains, fails closed, and returns UNKNOWN on EVERY PR — which is indistinguishable from a week with no PRs. Re-run install.sh (it installs the whole suite; the classifier ships with the 'wai' skill)."
  fi
else
  note "no $GATE_SH here — the merge gate is not installed in this repo, so nothing reads the shared domain classifier yet. Run install.sh if this repo is meant to have the suite."
fi

# ── Autonomy config — ABSENT IS A LEGITIMATE ANSWER; ARMED-BUT-UNGRANTABLE IS NOT ───────────────
# coordination.conf decides what an agent may do WITHOUT a human. Its every default is the SAFE
# state, and an ABSENT file means exactly what those defaults mean: autonomy off, comms none. So a
# missing file is NOT drift — it is the fail-closed default working as designed, and reporting it as
# a feature "silently off" would be false: off is the feature.
#
# The drift is the other shape, and it is invisible in both directions. AUTONOMY_ENABLED is
# affirmative — the human believes autonomy is armed and stops expecting to be asked — but the
# allowlist that AUTHORISES it is empty, or no human ever affirmed the blast radius. Autonomy
# eligibility is "every touched path is provably inside a human-affirmed safe set", never "the
# blocklist did not trip", so an empty AUTONOMY_SAFE_PATHS authorises NOTHING: the drain silently
# holds every PR and looks like an agent with nothing to do. coordination-lint.sh judges this
# properly when it runs — but it runs at SETUP time, and this file can rot at any time after.
#
# Read as affirmative: yes/true/on/1. The canonical value coordination-lint enforces is "yes", but a
# human who wrote `true` believes autonomy is on, and doctor's whole job is the gap between what the
# human believes is switched on and what actually is.
if [ ! -f "$COORD" ]; then
  note "no $COORD — autonomy is off and cross-repo comms is 'none' (the fail-closed default). That is a legitimate state, not drift; wai-init writes the file when you opt in."
elif [ ! -r "$COORD" ]; then
  unknown "$COORD exists but cannot be read — cannot tell whether autonomy is armed without its preconditions."
else
  AUT="$(conf_val AUTONOMY_ENABLED "$COORD" | tr '[:upper:]' '[:lower:]')"
  case "$AUT" in
    yes|true|on|1)
      SAFE="$(conf_val AUTONOMY_SAFE_PATHS "$COORD")"
      AFF="$(conf_val AUTONOMY_AFFIRMED "$COORD")"
      MISSING=""
      [ -n "$SAFE" ] || MISSING="AUTONOMY_SAFE_PATHS"
      [ -n "$AFF" ]  || MISSING="${MISSING:+$MISSING and }AUTONOMY_AFFIRMED"
      if [ -n "$MISSING" ]; then
        VERB="is empty"
        [ -n "$SAFE" ] || [ -n "$AFF" ] || VERB="are both empty"
        drift "AUTONOMY_ENABLED='$AUT' in $COORD but $MISSING $VERB → autonomy is configured ON and can never be granted: with no affirmed safe set every PR is held, and the drain looks like an agent that simply found nothing to do. Either fill it in (and re-run coordination-lint.sh) or set AUTONOMY_ENABLED=\"no\" so the config says what is true."
      else
        ok "autonomy is enabled and both its preconditions here are present (safe paths + affirmation); coordination-lint.sh judges the rest"
      fi
      ;;
    *) ok "autonomy is off (AUTONOMY_ENABLED='${AUT:-no}') — the fail-closed default" ;;
  esac
fi

# The learning ledger's in-repo fallback path. This is LEGITIMATE in CI/containers where ~/.claude
# is not writable, so it is an ADVISORY, not drift. On a workstation it usually means the ledger
# should migrate home and learning mode is off until it does — wai-learning-gap migrates it on its next
# invocation; doctor just surfaces it now instead of the next time you happen to run the skill.
if [ -f "temp/learning/ledger.md" ]; then
  note "a learning ledger sits at temp/learning/ (the in-repo fallback). If ~/.claude is writable, invoke wai-learning-gap to migrate it home — learning mode may be off until then."
fi

# Hooks that are committed but not WIRED. `.githooks/` is a directory like any other until
# `core.hooksPath` points at it — git looks in `.git/hooks` by default and will never run these.
# The suite advertises them as an enforcement layer, so a repo that carries them and does not run
# them is exactly what doctor is for: a feature that is silently off, indistinguishable from a repo
# that never wanted it. The suite's OWN repo shipped in this state. One line fixes it, so the
# finding carries the line.
if [ -d ".githooks" ]; then
  HP="$(git config --get core.hooksPath 2>/dev/null || true)"
  case "$HP" in
    .githooks|.githooks/) ok "git hooks are wired (core.hooksPath=$HP)" ;;
    "")  drift "'.githooks/' exists but core.hooksPath is unset — git runs .git/hooks, so the pre-commit and pre-push guards NEVER FIRE. Fix: git config core.hooksPath .githooks" ;;
    *)   drift "'.githooks/' exists but core.hooksPath='$HP' points elsewhere — the suite's guards never fire. Fix: git config core.hooksPath .githooks" ;;
  esac
fi

echo
RC=0
if [ "$DRIFT" = 1 ]; then
  echo "doctor: DRIFT — a feature is silently off until you act on the ✗ lines above."
  RC=1
fi
if [ "$UNVERIFIED" = 1 ]; then
  echo "doctor: UNKNOWN — the ? lines above could not be checked at all. That is a fact about doctor, not a clean bill of health for the repo."
  [ "$RC" = 0 ] && RC=2
fi
[ "$RC" = 0 ] && echo "doctor: no drift that disables a feature."
exit "$RC"
