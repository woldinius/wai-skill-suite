#!/usr/bin/env sh
# merge-gate.sh — the MECHANICAL preconditions for an agent-merged PR.
#
# `wai-pr-review` runs this and obeys the exit code. It exists because the alternative is asking a
# language model to remember six checks on every run, and "the model checked" is not a thing you
# can audit. This is.
#
#   exit 0  GO      — every mechanical precondition is met. The skill may merge (solo) or arm
#                     auto-merge (team) — IF its own review also found no Blocker/Major.
#   exit 1  NO-GO   — a precondition failed. The human merges. Reasons are printed.
#   exit 2  UNKNOWN — a precondition could not be verified. Also the human merges.
#
# THE FOUR RULES THIS FILE IS EDITED UNDER. Each one was bought with an incident; the incidents are
# in docs/rationale/merge-gate.md, deliberately NOT here — a comment is billed to the context window
# every time a model opens this file, and these rules are what an editor actually needs:
#
#   1. NO PATH FROM "I COULD NOT CHECK" TO GO. A gate that says OK when it is unsure is an
#      invitation, not a gate.
#   2. THE THREE STATES ARE THREE. NO-GO is a fact about the PR; UNKNOWN is a bug report about the
#      GATE. Fold them and you lose the only signal that says the gate needs fixing.
#   3. A GATE THAT HAS NEVER SAID GO IS NOT CAUTIOUS, IT IS BROKEN — and the breakage is invisible,
#      because "no" is what a working gate looks like. This one never said GO in two repos for its
#      entire existence, and nobody noticed for months. Test the PASS path first: tests/run.sh
#      case 1 is "green repo → GO", and it is first on purpose.
#   4. MECHANICS HERE, JUDGMENT IN THE MODEL. This script never decides whether a finding is a
#      Blocker. The gate is the CONJUNCTION: this script green AND no Blocker/Major.
#
# Usage:  sh merge-gate.sh [PR-number] [--repo OWNER/NAME]
#           PR-number defaults to the PR for the current branch.
#           --repo (or $GH_REPO) says WHICH repository to ask about. Without it the repo is read
#           from the git remote — which is a guess, and a wrong one costs a bogus verdict.
# Config: docs/architecture/merge-gate.conf   (written by wai-init; see the template there)

set -eu

# This script needs POSIX pattern semantics. zsh does NOT expand a variable's contents as a glob
# inside `case` (that needs GLOB_SUBST) — so under zsh every path check would silently match
# nothing, and a contract-domain PR would be reported clean. A gate that fails OPEN on the wrong
# shell is worse than no gate, so if we were launched under zsh, re-exec under sh.
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

# WHY THIS IS A SCRIPT AND NOT A PARAGRAPH IN A SKILL.md: "the model checked" cannot be grepped,
# diffed or audited — the failure case and the success case produce identical output (ADR-0002).
# And the line this script must not cross: IT OWNS MECHANICS, THE MODEL OWNS JUDGMENT.
# Why: docs/rationale/merge-gate.md § Why a script and not a paragraph

PR=""
REPO_SEL="${GH_REPO:-}"        # --repo, or $GH_REPO. Empty = read it from the git remote.
while [ $# -gt 0 ]; do
  case "$1" in
    # A VALUELESS --repo must not fall through to the remote guess. `--repo` exists precisely
    # because the local remote was wrong (a dead `origin`, work pushed to a second remote); a
    # silent fallback would restore the exact failure the flag was added to prevent, and the run
    # would look like it honoured the selector. Exit 2 — could not check, never a verdict.
    --repo)   shift
              [ $# -gt 0 ] && [ -n "${1:-}" ] || { echo "merge-gate: --repo needs a value (OWNER/NAME)" >&2; exit 2; }
              REPO_SEL="$1" ;;
    --repo=)  echo "merge-gate: --repo= needs a value (OWNER/NAME)" >&2; exit 2 ;;
    --repo=*) REPO_SEL="${1#--repo=}" ;;
    -*)       echo "merge-gate: unknown option '$1'" >&2; exit 2 ;;
    *)        [ -n "$PR" ] || PR="$1" ;;
  esac
  [ $# -gt 0 ] && shift
done

# DEFAULT PATHS ARE REPO-RELATIVE, NOT CWD-RELATIVE. The documented invocations run the suite's
# scripts "from this skill's directory"; resolved against the cwd, that produced a FALSE verdict
# ("no quality catalog" — in a repo that has one) and planted a stray gate-ledger inside
# .claude/skills/ — the very tree install.sh copies into every target repo (2026-08-18, live).
# So the default base is the enclosing git worktree; an explicit argument or env override still
# wins, and outside any repo the cwd stays the base (fixtures and bare dirs keep working).
# Deliberately --show-toplevel, NOT the --git-common-dir parent: rows belong to the worktree that
# produced them — consolidating across worktrees changes WHERE state lands, which was the ledger-home
# question's contested half (decided 2026-08-18: rows stay per-worktree, collected to main), not this fix's.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
CATALOG="${REPO_ROOT:-.}/docs/architecture/quality-attributes.md"

REASONS=""
VERDICT=0                       # 0 go · 1 no-go · 2 unknown

no_go()   { REASONS="$REASONS  ✗ $1\n";  [ "$VERDICT" -lt 1 ] && VERDICT=1; return 0; }
unknown() { REASONS="$REASONS  ? $1\n";  VERDICT=2; return 0; }
ok()      { REASONS="$REASONS  ✓ $1\n";  return 0; }
info()    { REASONS="$REASONS  · $1\n";  return 0; }   # stated, never a veto

# cap400 — bound a one-line string at 400 chars ON A WORD BOUNDARY with a visible '…'. The first
# cap was a silent `cut -c1-160`, and the ledger's first real row ended mid-token ("test (ubuntu-"):
# an amputation that reads exactly like a complete reason. The second review fixed the ledger cell
# and MISSED the classifier summary two hundred lines down — same cut, same cell, one level deeper.
# Both sites now share this one function so they cannot drift apart a third time.
cap400() { awk '{ if (length($0) <= 400) print; else { s = substr($0, 1, 400); sub(/ [^ ]*$/, "", s); print s "…" } }'; }

# emit_ledger LABEL WHY — append one row to the append-only gate ledger. $1 = verdict label
# (GO/NO-GO/UNKNOWN/MOOT), $2 = the raw reasons (may contain literal \n). The script writes the
# denominator so a human never has to remember to; the human adds only the outcome tag later, and
# the file's own header explains how. FAIL-OPEN, deliberately — the opposite of the gate itself: a
# logging failure must NEVER change a merge decision, so every line is best-effort and guarded.
# Losing a row is a data gap; blocking a correct merge because a file was read-only would be a real
# cost. (ADR-0002; docs/learnings/empirical-test-plan.md §0–1.)
emit_ledger() {
  _led="${MERGE_GATE_LEDGER:-${REPO_ROOT:-.}/docs/architecture/gate-ledger.md}"
  if [ ! -f "$_led" ]; then
    mkdir -p "$(dirname "$_led")" 2>/dev/null || true
    # A quoted heredoc: every line literal — backticks, dashes and all — so nothing is a printf
    # option or an expansion. The header carries its own tagging protocol, so it costs zero skill
    # words and cannot be lost.
    cat > "$_led" 2>/dev/null <<'LEDGER_HDR' || true
# Gate ledger

Every row is a verdict this repo's merge gate actually emitted — written by the SCRIPT, not by a
human who had to remember. That is the point: "the model checked" cannot be audited; this can. This
file is the **denominator** of the empirical phase (`docs/learnings/empirical-test-plan.md`, §0–1,
kept in the suite repo).

**APPEND-ONLY.** Never edit or delete a past row. The one thing you add is the `outcome` cell, later,
once you have acted on the PR:

- `ok` — the verdict matched your judgment (a GO you merged; a NO-GO you held or fixed).
- `fp` — **false positive:** a NO-GO you then merged UNCHANGED. The gate was too strict here.
- `fn` — **false negative:** a GO you later judged SHOULD have been blocked.
  **This is the measurement that matters. One `fn` outweighs ten `fp`.** It is the only thing that
  turns "suggestive" into "evidence", and no script can supply it — only you can.
  `fn` is defined on **GO rows only** — a NO-GO cannot be a "should have blocked and did not".
  A NO-GO that blocked for a reason outside the code (CI still running) is `nil`, not `fn`.
- `nil` — the verdict says **nothing about the code** (e.g. a NO-GO caused only by CI still
  running). Excluded from the fp/fn math; counted on its own line by `gate-stats.sh`.

Tags are matched on their **first two characters** — free text after a comma is welcome and
preserved. `ok, besser GO` is the calibration signal: the block was correct by the rules, but a GO
would have been fine here; `gate-stats.sh` counts it as its own metric. A field ledger once carried
20 such suffixed tags and a literal-match parser silently dropped every one — writing them was
never the mistake.

A `MOOT` row is a review that ran AFTER the PR was merged — the gate could prevent nothing. It is
not a decision; leave its outcome blank and do not count it in fp/fn. Its value is the opposite of
a missing row: it records that the gate *ran and was too late*, rather than reading as never-checked.

**Rows belong on the default branch (ledger-home decision, 2026-08-18).** The gate writes its row wherever it runs; a row left
on a feature branch rides that branch's stale copy of this file, and a later squash-merge has
deleted such rows twice. Collect loose rows into a small chore PR promptly.

**Weekly:** read the GO rows you merged. Any you would now block → tag `fn`. Do not skip this; the
`fn` count is the whole reason the ledger exists.

A verdict claimed in a review with **no matching row here** means the reviewer checked from memory
instead of running the gate (empirical-test-plan §0). That is itself a finding.

| when (UTC) | PR | verdict | why | outcome |
|---|---|---|---|---|
LEDGER_HDR
  fi
  # VERDICT REASONS FIRST: ✗ and ? before ✓ and ·, at ASSEMBLY TIME ONLY (the terminal keeps check
  # order, past rows are records). Under any cap the cell loses its LAST token, so a cell that spends
  # its budget on "everything fine" loses the reason it exists for. index()==1, not a regex: ✗ is
  # multibyte. Falls back to the raw reasons if the reorder fails — a data gap beats a lost verdict.
  # Why (field-measured, issue #10): docs/rationale/merge-gate.md § Verdict reasons first
  _srt=$(printf '%b' "$2" | awk '
    index($0, "  ✗ ") == 1 || index($0, "  ? ") == 1 { f[++nf] = $0; next }
    { r[++nr] = $0 }
    END { for (i = 1; i <= nf; i++) print f[i]; for (i = 1; i <= nr; i++) print r[i] }' 2>/dev/null) \
    || _srt=$(printf '%b' "$2")
  # Compact the reasons into one table-safe cell: newlines→';', pipes→'/', collapse spaces — then
  # cap400. The row stays one line (the awk in gate-stats.sh and the human's outcome cell both
  # depend on that); only the cell got wider, and a cut is now marked as one.
  _lw=$(printf '%s\n' "$_srt" | tr '\n' ';' | sed 's/|/\//g; s/[[:space:]]\{1,\}/ /g; s/^[ ;]*//; s/[ ;]*$//' | cap400)
  printf '| %s | %s | %s | %s | |\n' "$(date -u +%Y-%m-%dT%H:%MZ 2>/dev/null || echo '?')" "$PR" "$1" "$_lw" >> "$_led" 2>/dev/null || true
  # THE ROW BELONGS ON MAIN (the ledger-home decision, 2026-08-18). The ledger stays IN-REPO — numbers-lint
  # re-measures the repo's published ledger claims in CI, and a ledger in ~/.claude would break
  # that loop — but an append-only file written on whatever branch is checked out has LOST a row
  # twice in squash races (#28, #31), and one field repo invented this rule by hand in its
  # CLAUDE.md. So the script says it, every time it lands a row anywhere but the default branch:
  # collect loose rows into a small chore PR promptly. Fail-open: no git answer, no note.
  _cur="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  _def="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')" || true
  [ -n "$_def" ] || _def=main
  if [ -n "$_cur" ] && [ "$_cur" != "$_def" ]; then
    echo "note: this ledger row landed on branch '$_cur' — ledger rows belong on $_def (ledger-home decision). Collect loose rows into a small chore PR promptly: a stale branch copy has deleted rows in a squash race twice (#28, #31)."
  fi
}

# emit_runlog LABEL — ONE attendance row beside the verdict (issue #11: the record measures side
# effects, not work — and a gate verdict is the one side effect a review run reliably has, so the
# run log's row for wai-pr-review is written HERE, where the script↔skill mapping is 1:1). Resolved
# as a ../../wai/scripts/ sibling exactly like the domain classifier below. FAIL-OPEN for
# emit_ledger's reason: a missing or failing logger must never change a merge decision.
RUNLOG_SH="$(dirname "$0")/../../wai/scripts/run-log.sh"
emit_runlog() {
  [ -f "$RUNLOG_SH" ] && sh "$RUNLOG_SH" wai-pr-review "PR #$PR" "$1" >/dev/null 2>&1 || true
}

# --- 0. Toolchain -------------------------------------------------------------------------------
command -v gh  >/dev/null 2>&1 || { echo "merge-gate: gh is not installed — cannot verify anything." >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "merge-gate: git is not installed." >&2; exit 2; }
gh auth status >/dev/null 2>&1 || { echo "merge-gate: gh is not authenticated — cannot verify anything." >&2; exit 2; }

if [ -z "$PR" ]; then
  PR="$(gh pr view --json number --jq .number 2>/dev/null || true)"
  [ -n "$PR" ] || { echo "merge-gate: no PR given and none found for the current branch." >&2; exit 2; }
fi

# --- 0b. WHICH repository, and WHICH base? ------------------------------------------------------
# Guarded on TWO conditions, because there are two ways to get nothing: a non-zero exit, and a
# SUCCESSFUL call that printed nothing. Either one is UNKNOWN, never NO-GO — unguarded under `set -e`
# a gh failure exits 1, which is THIS gate's code for NO-GO, and a tool failure then reads as a
# verdict about the code. Why: docs/rationale/merge-gate.md § Repo and base resolution
if [ -n "$REPO_SEL" ]; then
  REPO="$REPO_SEL"                              # told explicitly — no guessing, nothing to fail
elif ! REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || [ -z "$REPO" ]; then
  echo "merge-gate: could not resolve WHICH repository to ask about." >&2
  echo "  Looked it up from this checkout's git remote via 'gh repo view'; it failed or printed nothing." >&2
  echo "  This is a TOOL failure, not a verdict. Say which repo explicitly:" >&2
  echo "      sh merge-gate.sh $PR --repo OWNER/NAME     (or export GH_REPO=OWNER/NAME)" >&2
  echo "  If the checkout has several remotes, 'gh repo set-default OWNER/NAME' fixes it for good." >&2
  exit 2
fi

if ! BASE="$(gh pr view "$PR" --repo "$REPO" --json baseRefName --jq .baseRefName 2>/dev/null)" || [ -z "$BASE" ]; then
  echo "merge-gate: could not resolve PR #$PR in '$REPO' — 'gh pr view' failed or printed nothing." >&2
  echo "  This is a TOOL failure, not a verdict. Check the PR number and the repository:" >&2
  echo "      sh merge-gate.sh <PR> --repo OWNER/NAME" >&2
  exit 2
fi

# --- Is the PR already merged? Then this gate is MOOT --------------------------------------------
# Once the PR IS merged this gate can prevent nothing: GO would mean "you may merge" (already done),
# NO-GO "do not merge" (too late). Neither is honest. A MOOT row is the opposite of a missing one —
# it records that the gate ran and was TOO LATE, rather than reading as never-checked. No artefact
# else watches ORDERING, and a solo repo can merge before the review runs.
STATE="$(gh pr view "$PR" --repo "$REPO" --json state --jq .state 2>/dev/null || echo UNKNOWN)"
if [ "$STATE" = "MERGED" ]; then
  echo "merge-gate: PR #$PR ($REPO → $BASE) is already MERGED — this gate is MOOT."
  echo "  Nothing is left to prevent. Any review findings are FOLLOW-UPS, not gate conditions."
  echo "  If you authored this code, this is a self-review of your own just-merged work."
  emit_ledger MOOT "PR already merged before the gate ran"
  emit_runlog MOOT
  echo "VERDICT: MOOT — the PR was merged before the gate ran; the human owns any follow-up."
  exit 2
fi

# --- 1. The quality catalog must exist ----------------------------------------------------------
# A missing catalog means no agreed standard, no repo mode, and no evidence a human ever set this
# repo up. The `solo` default covers a missing LINE in a catalog someone accepted — not a missing
# catalog.
if [ -f "$CATALOG" ]; then
  ok "quality catalog present"
else
  no_go "no $CATALOG — run wai-init before an agent merges anything here"
fi

# --- 2. Repo mode -------------------------------------------------------------------------------
MODE="solo"
if [ -f "$CATALOG" ]; then
  m="$(sed -n 's/.*\*\*Repo mode:\*\*[[:space:]]*\([a-z]*\).*/\1/p' "$CATALOG" | head -1)"
  [ -n "$m" ] && MODE="$m"
fi
case "$MODE" in
  solo|team) ok "repo mode: $MODE" ;;
  *) unknown "repo mode '$MODE' is not solo|team" ; MODE="team" ;;   # unknown ⇒ treat as the stricter one
esac

# --- 3. Every check the base branch REQUIRES is SUCCESS -----------------------------------------
# GREEN MEANS: every check the base branch REQUIRES is SUCCESS. Everything else is informational and
# must never veto. A REQUIRED check that is SKIPPED is a NO-GO — deliberately stricter than GitHub,
# and the reason "just treat SKIPPED as green" is not the fix: it opens skip-to-green.
# Why: docs/rationale/merge-gate.md § Required checks and skip-to-green
required_from_rulesets() {
  ids="$(gh api "repos/$REPO/rulesets?includes_parents=true" --jq '.[].id' 2>/dev/null)" || return 0
  printf '%s\n' "$ids" | while IFS= read -r id; do
    # AN ERROR BODY IS NOT AN ID. `gh api` prints its 404/403 JSON to STDOUT and exits non-zero, so
    # a naive `|| true` reads `{"message":"Not Found"}` in as a required check name — and the gate
    # then blocks forever on a check that "did not report". Only digits get through.
    case "$id" in ''|*[!0-9]*) continue ;; esac
    gh api "repos/$REPO/rulesets/$id" \
      --jq '.rules[]? | select(.type=="required_status_checks")
            | .parameters.required_status_checks[]?.context' 2>/dev/null || true
  done
}
REQUIRED="$(required_from_rulesets | grep -v '^$' | sort -u || true)"
if [ -z "$REQUIRED" ]; then                        # legacy branch protection, same guard
  if BP="$(gh api "repos/$REPO/branches/$BASE/protection" \
           --jq '.required_status_checks.contexts[]?' 2>/dev/null)"; then
    REQUIRED="$(printf '%s\n' "$BP" | grep -v '^$' | sort -u || true)"
  fi
fi

CHECKS="$(gh pr checks "$PR" --repo "$REPO" --json name,state --jq '.[] | "\(.state)\t\(.name)"' 2>/dev/null || true)"

if [ -z "$CHECKS" ]; then
  no_go "no CI checks report on this PR — zero checks is not 'green'; run wai-cicd"
elif [ -n "$REQUIRED" ]; then
  N_REQ="$(printf '%s\n' "$REQUIRED" | grep -c . || true)"
  # ONE awk, TWO STREAMS, separated by a control byte no check name can contain.
  #
  # The shell-loop version of this was written first and it did not survive contact: a check name may
  # contain spaces (`Lint (all workspaces)`), so `for r in $REQUIRED` word-splits it and every such
  # check silently becomes "did not report" — a permanent NO-GO nobody can explain. Rewriting it with
  # `while IFS= read -r` fixed that and introduced a second one: a `case ... esac` inside a `$( )` is
  # a syntax error in bash 3.2, which is what /bin/sh IS on macOS. shellcheck passed it. Running it
  # did not. awk has neither problem, and it does the whole job in one process.
  #
  # (Not `-v req="$REQUIRED"`: BSD awk rejects a newline inside a -v assignment — "newline in string".
  # Tested, not assumed.)
  BAD="$({ printf '%s\n' "$REQUIRED"; printf '\034\n'; printf '%s\n' "$CHECKS"; } | awk -F'\t' '
           !seen && $0 == "\034" { seen = 1; next }
           !seen                 { if ($0 != "") REQ[++nr] = $0; next }
                                 { S[$2] = $1 }
           END { for (i = 1; i <= nr; i++) { r = REQ[i]
                   if (!(r in S))       { print r "=DID-NOT-REPORT"; continue }
                   if (S[r] != "SUCCESS") print r "=" S[r] } }')"
  if [ -z "$BAD" ]; then
    ok "all $N_REQ check(s) $BASE requires are SUCCESS"
  else
    no_go "required check(s) not green: $(printf '%s' "$BAD" | tr '\n' ' ')"
  fi
  # A non-required check that failed does not veto — but it is not nothing, and swallowing it is how
  # a gate teaches people that its silence means "fine".
  INFO="$({ printf '%s\n' "$REQUIRED"; printf '\034\n'; printf '%s\n' "$CHECKS"; } | awk -F'\t' '
            !seen && $0 == "\034" { seen = 1; next }
            !seen                 { if ($0 != "") REQ[$0] = 1; next }
            $2 == "" || ($2 in REQ)                               { next }
            $1 == "SUCCESS" || $1 == "SKIPPED" || $1 == "NEUTRAL" { next }
                                  { print $2 "=" $1 }')"
  [ -z "$INFO" ] || info "not required by $BASE, so not blocking — but not green either: $(printf '%s' "$INFO" | tr '\n' ' ')"
else
  # The required set could not be read, or the branch declares none. Either way we cannot tell a
  # deliberately-skipped job from a suppressed one, so the only safe definition of green left is the
  # strict one. Fail closed — and name the repair, because this state is fixable.
  TOTAL="$(printf '%s\n' "$CHECKS" | grep -c . || true)"
  NOTGREEN="$(printf '%s\n' "$CHECKS" | awk -F'\t' '$1 != "SUCCESS" { print $2 "=" $1 }')"
  BAD="$(printf '%s\n' "$NOTGREEN" | grep -c . || true)"
  if [ "$BAD" -eq 0 ]; then
    ok "$TOTAL CI check(s), all SUCCESS ($BASE declares no required checks — strict rule applied)"
  else
    no_go "$BASE declares no required status checks, so EVERY reported check must be SUCCESS — $BAD of $TOTAL are not: $(printf '%s' "$NOTGREEN" | tr '\n' ' ')"
    # A REPAIR HINT IS NOT AN UNKNOWN. This branch DID check, and the answer was no — that is a
    # NO-GO. Emitting the hint through unknown() silently upgraded the verdict and made the gate
    # misreport which of the three things had happened. Caught by tests/run.sh on its first run.
    info "→ declare required checks on $BASE (wai-cicd / wai-init). The gate then judges only those, and a build job that runs on main only stops blocking every PR."
  fi
fi

# --- 4. team mode: an approval rule must actually be ENFORCED on the base branch -----------------
# `gh pr merge --auto` merges the moment nothing is outstanding. With no rule requiring a review,
# that moment is NOW — and the "a second human approved it" guarantee silently evaporates while
# the run claims to be waiting for one.
if [ "$MODE" = "team" ]; then
  APPROVALS=""
  RS="$(gh api "repos/$REPO/rulesets?includes_parents=true" 2>/dev/null || true)"
  if [ -n "$RS" ]; then
    for id in $(printf '%s' "$RS" | grep -o '"id":[0-9]*' | cut -d: -f2); do
      n="$(gh api "repos/$REPO/rulesets/$id" 2>/dev/null \
           | grep -o '"required_approving_review_count":[0-9]*' | cut -d: -f2 | head -1 || true)"
      [ -n "$n" ] && [ "$n" -ge 1 ] && APPROVALS="$n" && break
    done
  fi
  if [ -z "$APPROVALS" ]; then
    BP="$(gh api "repos/$REPO/branches/$BASE/protection" 2>/dev/null || true)"
    APPROVALS="$(printf '%s' "$BP" | grep -o '"required_approving_review_count":[0-9]*' | cut -d: -f2 | head -1 || true)"
  fi
  if [ -n "$APPROVALS" ] && [ "$APPROVALS" -ge 1 ]; then
    ok "team mode: $BASE enforces $APPROVALS approving review(s)"
  else
    no_go "team mode, but no enforced approval rule on '$BASE' — do NOT arm auto-merge, it would merge at once"
  fi
fi

# --- 5. Excluded domains — DELEGATED to the one shared classifier -------------------------------
# ONE definition, never three copies: this gate, pr-review and wai-team's drain all ask the same
# question, and the copy that fails OPEN is the one that wins. The GUARDRAIL floor stays hardcoded
# INSIDE the classifier, so no repo config can lower it. §4 (team-mode approval) deliberately did
# NOT move: that is a fact about branch PROTECTION, not about the diff's domain.
# FAIL CLOSED: classifier missing, or UNKNOWN because it could not read the diff → this gate is
# UNKNOWN and the human merges. There is no path from "I could not classify" to GO.
# Why, and what EX-GDPR closed: docs/rationale/merge-gate.md § Excluded domains: one classifier
CONF="${REPO_ROOT:-.}/docs/architecture/merge-gate.conf"
EXCL_SH="$(dirname "$0")/../../wai/scripts/excluded-domains.sh"
if [ ! -f "$CONF" ]; then
  # The gate needs its config to know which paths are contract-domain. Absent conf = it cannot
  # classify = UNKNOWN (never GO) — the same fail-closed state doctor.sh reports as drift.
  unknown "no $CONF — cannot tell which paths are contract-domain; wai-init writes it"
elif [ ! -f "$EXCL_SH" ]; then
  unknown "cannot find the shared domain classifier at $EXCL_SH — cannot tell which paths are excluded domains"
else
  # Capture stdout+stderr AND the exit code under `set -e`. The form `v=$(cmd) && rc=0 || rc=$?` is
  # the ONE that survives a non-zero exit here: a bare `rc=$?` on the next line would let set -e kill
  # the script the instant the classifier says EXCLUDED (exit 1) — turning a correct NO-GO into a
  # crash. (The same class of bug ADR-0002 keeps re-teaching; tests/run.sh covers it.)
  # PASS THE REPO ON. §0b-§4 above judge "$REPO"; if this delegation does not carry it, the
  # classifier falls back to gh's default remote and can read a DIFFERENT repository's PR of the
  # same number — reporting CLEAR on a diff this gate never saw. That was the one fail-OPEN path in
  # a script whose every other unresolvable state returns 2 and holds.
  EXCL_OUT="$(sh "$EXCL_SH" --pr "$PR" --repo "$REPO" 2>&1)" && EXCL_RC=0 || EXCL_RC=$?
  # Prefer the classifier's own parseable summary line (`EXCLUDED-DOMAINS: EX-PAY EX-GDPR`); fall
  # back to its flattened output so an UNKNOWN still carries its reason into the ledger.
  EXCL_SUM="$(printf '%s\n' "$EXCL_OUT" | grep '^EXCLUDED-DOMAINS:' | head -1 | sed 's/^EXCLUDED-DOMAINS:[[:space:]]*//' || true)"
  [ -n "$EXCL_SUM" ] || EXCL_SUM="$(printf '%s' "$EXCL_OUT" | tr '\n' ' ' | sed 's/[[:space:]]\{1,\}/ /g; s/^ *//; s/ *$//' | cap400)"
  # An ADVISORY on exit 0 must survive INTO the verdict and the ledger row — the citation dial's
  # whole bargain is "visible without deciding", and the first version of this branch swallowed it:
  # the classifier printed ADVISORY-DOMAINS and the gate replaced it with a fixed all-clear line,
  # so the one output the human actually reads lost the visibility the decision was made for.
  # info(), not a veto — stated, never blocking. (Found by the adversarial re-review of the PR
  # that introduced the dial.)
  EXCL_ADV="$(printf '%s\n' "$EXCL_OUT" | grep '^ADVISORY-DOMAINS:' | head -1 | sed 's/^ADVISORY-DOMAINS:[[:space:]]*//' || true)"
  case "$EXCL_RC" in
    0) ok "no excluded domain touched (guardrail floor, contract domain, destructive migration, erasure)"
       [ -z "$EXCL_ADV" ] || info "advisory (not gating, citation dial): $EXCL_ADV cited without declared paths — visible here so it reaches the ledger row" ;;
    1) no_go "touches an excluded domain — the human merges these, always: $EXCL_SUM" ;;
    *) unknown "the domain classifier could not verify this PR (fail closed): $EXCL_SUM" ;;
  esac
fi

# --- Verdict ------------------------------------------------------------------------------------
echo "merge-gate: PR #$PR ($REPO → $BASE, mode: $MODE)"
printf '%b' "$REASONS"
case "$VERDICT" in
  0) echo "VERDICT: GO — mechanical preconditions met. Merge only if your review also found no Blocker/Major." ;;
  1) echo "VERDICT: NO-GO — a precondition failed. Leave the PR for the human." ;;
  2) echo "VERDICT: UNKNOWN — a precondition could not be verified. Leave the PR for the human." ;;
esac

# --- Emit to the ledger -------------------------------------------------------------------------
# The gate writes its OWN verdict to an append-only ledger, for the exact reason the gate exists:
# "the model checked" cannot be audited, but a line the SCRIPT wrote can. The row is written by
# emit_ledger() (defined near the top, and also called on the MOOT short-circuit).
# PLAIN case — NOT `_v=$(case … esac)`. A case inside $() is a syntax error in bash 3.2, which is
# what /bin/sh IS on macOS; shellcheck passes it, the shell does not. This is the FOURTH artefact in
# the suite to relearn that (ADR-0002), and tests/run.sh caught it on the first run — as designed.
case "$VERDICT" in 0) _v=GO ;; 1) _v=NO-GO ;; 2) _v=UNKNOWN ;; *) _v='?' ;; esac
emit_ledger "$_v" "$REASONS"
emit_runlog "$_v"

exit "$VERDICT"
