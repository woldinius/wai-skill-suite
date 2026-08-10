#!/usr/bin/env sh
# merge-gate.sh — the MECHANICAL preconditions for an agent-merged PR.
#
# `wai-pr-review` runs this and obeys the exit code. It exists because the alternative is
# asking a language model to remember six checks on every run, and "the model checked" is not a
# thing you can audit. This is.
#
#   exit 0  GO      — every mechanical precondition is met. The skill may merge (solo) or arm
#                     auto-merge (team) — IF its own review also found no Blocker/Major.
#   exit 1  NO-GO   — a precondition failed. The human merges. Reasons are printed.
#   exit 2  UNKNOWN — a precondition could not be verified. Also the human merges.
#
# There is no path from "I could not check" to "go". A gate that says OK when it is unsure is an
# invitation, not a gate.
#
# ── A GATE THAT HAS NEVER SAID GO IS NOT CAUTIOUS. IT IS BROKEN — AND THE BREAKAGE IS INVISIBLE,
#    BECAUSE "NO" IS WHAT A WORKING GATE LOOKS LIKE. ────────────────────────────────────────────
#
# This gate never said GO. Not once, in two repos, for its entire existence: it read `SKIPPED` as a
# failure, and the suite's own CI template ships a job skipped on every PR. The auto-merge path —
# the whole reason it exists — shipped DEAD, and nobody noticed for months.
#
# ON 2026-07-15 IT SAID GO. The first one, in any repo, ever — and it fell to the PR that documented
# that it never had. The gate is now a validated branch and not merely a hopeful one; keep that
# sentence in the past tense, and keep the date, because "it has never said GO" was TRUE when it was
# written and would be a lie today. A claim in a comment rots exactly like a claim in a document.
#
# The model declined to merge it anyway — docs about its own errors, corrected twice in ten minutes,
# were not its to land unread. Both halves were green and it still said no. That is not a rule being
# dodged. THAT IS THE JUDGMENT HALF OF THE CONJUNCTION DOING ITS JOB, and it is the only recorded
# instance of it. (docs/learnings/field-reports/2026-07-15-backend-web-das-gate-hat-go-gesagt.md)
#
# A gate has four ways to be wrong. Only ONE of them is loud:
#
#   says GO when it should say NO   → something bad merges. You find out. Everyone designs for this.
#   says NO-GO when it should say GO → NOTHING HAPPENS. Which is what a gate looks like. Nobody does.
#   right verdict, wrong reason      → nobody does.
#   an answer you cannot audit       → "the model checked". Nobody does.
#
# Gates do not die by letting something through. They die by becoming decoration people route around.
# So: everyone tests that it BLOCKS — the easy path, and the one that fails safe. Almost nobody tests
# that it PASSES, and the pass path carries the gate's entire value. If your test plan has no case
# that says "here is a PR that SHOULD get GO, and it does", you have tested half the machine.
# (tests/run.sh case 1 is that case, and it exists because of this.)
#
# AND THE THREE STATES ARE THREE, NOT TWO. The temptation is to fold UNKNOWN into NO-GO — both mean
# "the human merges", so why distinguish? Because they are statements about different things:
#
#   NO-GO   is a fact about the PR.        It failed a check.
#   UNKNOWN is a bug report about the GATE. It could not check.
#
# Fold them and you throw away the only signal that says the gate needs fixing — which is exactly the
# signal that was missing for the months it never said GO. And folding the other way is worse: a
# repair HINT once went out through unknown(), silently upgrading a definite NO-GO to "I couldn't
# tell". Never unsafe. But a gate that misreports which of its own states it is in is a gate people
# stop reading.
#
# Fail closed — and then go and check whether "closed" is where it has been the whole time.
#
# What this script does NOT decide: whether a finding is a Blocker. That is judgment, and it stays
# with the reviewer. The gate is the CONJUNCTION of both: this script green AND no Blocker/Major.
#
# Usage:  sh merge-gate.sh [PR-number] [--repo OWNER/NAME]
#           PR-number defaults to the PR for the current branch.
#           --repo (or $GH_REPO) says WHICH repository to ask about. Without it the repo is read
#           from the git remote — which is a guess, and a wrong one costs a bogus verdict (below).
# Config: docs/architecture/merge-gate.conf   (written by wai-init; see the template there)

set -eu

# This script needs POSIX pattern semantics. zsh does NOT expand a variable's contents as a glob
# inside `case` (that needs GLOB_SUBST) — so under zsh every path check would silently match
# nothing, and a contract-domain PR would be reported clean. A gate that fails OPEN on the wrong
# shell is worse than no gate, so if we were launched under zsh, re-exec under sh.
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

# WHY THIS IS A SCRIPT AND NOT A PARAGRAPH IN A SKILL.md
#   Anthropic, "Effective context engineering for AI agents": *hardcoding complex, brittle logic
#   in prompts to elicit exact agentic behavior creates fragility.* This gate used to be six
#   conditions a model had to remember on every run — and "the model checked" is not something
#   anyone can audit. You cannot grep it, you cannot diff it, and six months on you cannot answer
#   whether it happened: the failure case and the success case produce identical output.
#   → docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md · REFERENCES.md
#
#   And the line this script must not cross: IT OWNS MECHANICS, THE MODEL OWNS JUDGMENT. No
#   script can decide whether a finding is a Blocker. The gate is one half of a conjunction.

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

CATALOG="docs/architecture/quality-attributes.md"

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
  _led="${MERGE_GATE_LEDGER:-docs/architecture/gate-ledger.md}"
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
- `fn` — **false negative:** a GO (or a clean review) you later judged SHOULD have been blocked.
  **This is the measurement that matters. One `fn` outweighs ten `fp`.** It is the only thing that
  turns "suggestive" into "evidence", and no script can supply it — only you can.

A `MOOT` row is a review that ran AFTER the PR was merged — the gate could prevent nothing. It is
not a decision; leave its outcome blank and do not count it in fp/fn. Its value is the opposite of
a missing row: it records that the gate *ran and was too late*, rather than reading as never-checked.

**Weekly:** read the GO rows you merged. Any you would now block → tag `fn`. Do not skip this; the
`fn` count is the whole reason the ledger exists.

A verdict claimed in a review with **no matching row here** means the reviewer checked from memory
instead of running the gate (empirical-test-plan §0). That is itself a finding.

| when (UTC) | PR | verdict | why | outcome |
|---|---|---|---|---|
LEDGER_HDR
  fi
  # Compact the reasons into one table-safe cell: newlines→';', pipes→'/', collapse spaces — then
  # cap400. The row stays one line (the awk in gate-stats.sh and the human's outcome cell both
  # depend on that); only the cell got wider, and a cut is now marked as one.
  _lw=$(printf '%b' "$2" | tr '\n' ';' | sed 's/|/\//g; s/[[:space:]]\{1,\}/ /g; s/^[ ;]*//; s/[ ;]*$//' | cap400)
  # The stamp is date-only by design: T00:00Z, never the wall-clock hour. The ledger is a public,
  # append-only artefact, and a real hour in it is a record of WHEN A HUMAN WORKED, not of the
  # verdict. See docs/time-normalization.md. Ordering within a day comes from the append order.
  printf '| %s | %s | %s | %s | |\n' "$(date -u +%Y-%m-%dT00:00Z 2>/dev/null || echo '?')" "$PR" "$1" "$_lw" >> "$_led" 2>/dev/null || true
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
# THESE TWO LINES USED TO BE UNGUARDED, AND UNDER `set -e` THAT MADE A TOOL FAILURE LOOK LIKE A
# JUDGMENT. `gh` exits 1 when it cannot resolve a repository; `set -e` then killed the script with
# gh's exit code — and 1 is this gate's code for NO-GO. In the field: `origin` pointed at a repo the
# human had lost access to, the PR lived on a second remote, and the gate reported
# "a precondition failed" for a PR it had never even looked at.
#
# That is the exact failure this script's own header calls unforgivable: the three states are three,
# and "I could not check" is state 2. Reporting it as state 1 is corrosive in BOTH directions — the
# human reads a network error as a content verdict, and then learns to discount NO-GO ("that's just
# the remote"), which is the state the gate protects `main` with.
#
# Guarded on TWO conditions, because there are two ways to get nothing: a non-zero exit, and a
# SUCCESSFUL call that printed nothing (the same class as a scanner whose empty output reads as
# "zero findings"). Either one is UNKNOWN.
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
# The gate answers one question: "may this be merged?" Once the PR IS merged, that question is
# already answered and the gate can prevent nothing — a GO would imply "you may merge" (already
# done) and a NO-GO "do not merge" (too late). Neither is honest, so say MOOT and stop. No artefact
# watches ORDERING, and this is the one place the gate can: a solo repo can merge before the review
# runs, turning the review into a post-merge self-review of just-authored code — the weakest
# configuration there is. Recording a MOOT row is the opposite of a missing one: a missing row reads
# as "never checked", a MOOT row says "checked, too late". (Field report: a production iOS repo, 2026-08.)
STATE="$(gh pr view "$PR" --repo "$REPO" --json state --jq .state 2>/dev/null || echo UNKNOWN)"
if [ "$STATE" = "MERGED" ]; then
  echo "merge-gate: PR #$PR ($REPO → $BASE) is already MERGED — this gate is MOOT."
  echo "  Nothing is left to prevent. Any review findings are FOLLOW-UPS, not gate conditions."
  echo "  If you authored this code, this is a self-review of your own just-merged work."
  emit_ledger MOOT "PR already merged before the gate ran"
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
# GREEN MEANS: every check the base branch REQUIRES is SUCCESS. Everything else is informational
# and must never veto.
#
# The old rule was "every reported check must be SUCCESS", which treats SKIPPED as a failure. It is
# not one — SKIPPED means the job's own condition said "do not run". And the suite's OWN ci.yml
# ships a build job gated on `github.ref == 'refs/heads/main'`, so on a PR that job is skipped and
# GitHub still reports a check run with conclusion `skipped`. Result: every PR in every repo carried
# a permanently non-green check, and this gate returned NO-GO on all of them, forever. The
# auto-merge path the whole suite is built around shipped DEAD. (Reproduced on two PRs, two repos.)
#
# THE OBVIOUS FIX IS A TRAP. "Treat SKIPPED as green" opens SKIP-TO-GREEN: put a `paths-ignore` on
# the test job, and an API PR skips it, the gate calls it green, and the required check never ran.
# Same evasion class the stub guard was just hardened against. A fix that swaps one hole for another
# is not a fix.
#
# So: ask the branch what it REQUIRES, and judge only that. A required check that is SKIPPED is a
# NO-GO — deliberately stricter than GitHub, which lets a skipped required check pass.
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
#
# Three checks used to live here, inline: the hardcoded GUARDRAIL floor, the repo's CONTRACT_PATHS,
# and destructive migrations. They now live in ONE place — the shared classifier next to doctor.sh
# (`../../wai/scripts/excluded-domains.sh`) — and this gate CALLS it. The reason is
# single-source. The same question — "is this an excluded domain, the human's alone?" — is asked by
# THIS everyday gate, by pr-review, and by wai-team's autonomous drain. Three inline copies are
# three chances to disagree about what is human-only, and the copy that fails OPEN is the one that
# wins. One definition, cited from the canonical `agent-git-protocol.md` § "Excluded domains",
# cannot drift against itself.
#
# WHAT MOVED, AND WHAT DID NOT:
#   • The hardcoded GUARDRAIL_PATHS floor moved INTO the classifier — still hardcoded there, so
#     config STILL cannot lower it. The two-harmless-steps escalation (an agent PR "tidies"
#     merge-gate.conf, drops billing/* from CONTRACT_PATHS, then merges billing freely) is closed in
#     the floor's new home, not reopened here. EX-PAY/AUTH/API/SEC (CONTRACT_PATHS), EX-MIG
#     (MIGRATION_PATHS + a destructive-DDL grep) and the NEW EX-GDPR all live there too.
#   • EX-GDPR is the hole this refactor closes. The classifier reads a new ERASURE_PATHS key AND
#     greps the WHOLE diff for erasure — so an ad-hoc `DELETE FROM users`, `ON DELETE CASCADE` or
#     `deleteAccount()` dropped OUTSIDE any migration file is caught. A path-only check let that
#     self-merge through; a whole-diff grep does not.
#   • §4 (team-mode approval enforcement) did NOT move, and must not. It is a fact about branch
#     PROTECTION, not about the diff's domain — a different question with a different source of
#     truth. It stays above this block, in this script, exactly where it was.
#
# FAIL CLOSED. The classifier is located from THIS script's own path (not from the cwd, which is the
# repo root). If it cannot be found, or it returns UNKNOWN because it could not read the diff, this
# gate is UNKNOWN and the human merges. There is no path from "I could not classify" to GO — the
# rule the whole gate lives by. pr-review inherits EX-GDPR for free: it obeys this exit code, it
# does not re-derive the domain set.
CONF="docs/architecture/merge-gate.conf"
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
  case "$EXCL_RC" in
    0) ok "no excluded domain touched (guardrail floor, contract domain, destructive migration, erasure)" ;;
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

exit "$VERDICT"
