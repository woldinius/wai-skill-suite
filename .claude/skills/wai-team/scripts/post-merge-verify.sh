#!/usr/bin/env sh
# post-merge-verify.sh — the HARD SERIAL BARRIER between one autonomous merge and the next.
#
# Autonomous integration is opt-in and strictly serial for exactly one reason: after a merge lands on
# main, the ONLY safe thing to do before merging anything else is to prove main is still green. Skip
# that, and a bad merge is compounded by every merge stacked on top of it before anyone looks — the
# blast radius of one mistake becomes the whole run. So the run does not continue until THIS returns
# 0. It is a barrier, not a check you can note-and-move-past, and it is why autonomous mode may not
# combine with bounded parallelism: two merges in flight have no single "main is green" moment to
# verify. (Blueprint §4; wai-team SKILL "Autonomous integration".)
#
# THE SPLIT (ADR-0002). This script owns MECHANICS: resolve the project's test command, confirm the
# just-merged commit is actually in the tree we are about to test, run the command, and report
# green/red/unknown. It does NOT own JUDGMENT — whether to REVERT the offending merge or leave it
# flagged for the human is the orchestrator's call on a red/unknown result. Evidence here; the
# revert-or-flag decision there.
#
# FAIL CLOSED. This is a gate, so an un-run verification NEVER reads as green:
#
#   exit 0  main is green — the barrier lifts, the next autonomous merge may proceed.
#   exit 1  main is RED — a test the project defines failed after the merge. STOP the whole run.
#   exit 2  UNKNOWN — the barrier could not verify green (no resolvable test command, the test tool
#           is not installed, the merged commit is not in HEAD's history, or this is not a git repo).
#           STOP the whole run. "I could not check" is never "it is fine" — that is the entire point
#           of a barrier, and folding UNKNOWN into green is how a run marches on over a broken main.
#
# Both exit 1 and exit 2 STOP the run. The distinction is a message to the human, not to the run:
# exit 1 says "the merge broke a test", exit 2 says "the barrier itself could not run" — two very
# different repairs, and collapsing them throws away the signal that the verification is misconfigured.
#
# Resolving the test command: $TEST_CMD wins if set (the explicit escape hatch for an unusual repo);
# otherwise it is auto-detected from the ecosystem. $MAIN_BRANCH overrides the base-branch name (for
# the advisory note only; the real guarantee is the ancestor check, not the branch name).
#
# Usage: sh post-merge-verify.sh <merged-commit-or-PR>
#   e.g. sh post-merge-verify.sh 9f3a1c2      or      sh post-merge-verify.sh 142   (a PR number)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX word/glob semantics required

fail_unknown() { echo "post-merge-verify: UNKNOWN — $1" >&2; echo "VERDICT: UNKNOWN — STOP the run; the barrier could not verify main is green (fail-closed)."; exit 2; }

ARG="${1:-}"
[ -n "$ARG" ] || { echo "post-merge-verify: need <merged-commit-or-PR>." >&2; fail_unknown "no merged commit/PR given"; }

command -v git >/dev/null 2>&1 || fail_unknown "git is not installed"
git rev-parse --git-dir >/dev/null 2>&1 || fail_unknown "not inside a git repository"

# Run at the repository root so ecosystem detection and the test command see the whole project.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || fail_unknown "could not resolve the repository root"
cd "$ROOT" 2>/dev/null || fail_unknown "could not cd to the repository root ($ROOT)"

# --- Resolve the merged commit -----------------------------------------------------------------
# The barrier verifies the state AFTER a specific merge. It must therefore prove that merge is in
# the tree it is about to test — otherwise a green result would be about the wrong code. Accept a
# rev (SHA/tag/ref) directly; fall back to resolving a bare PR number via gh.
TARGET="$(git rev-parse --verify --quiet "${ARG}^{commit}" 2>/dev/null || true)"
if [ -z "$TARGET" ]; then
  case "$ARG" in
    ''|*[!0-9]*) : ;;                                  # not a pure number → not a PR number
    *)
      if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        MC="$(gh pr view "$ARG" --json mergeCommit --jq '.mergeCommit.oid' 2>/dev/null || true)"
        [ -n "$MC" ] && TARGET="$(git rev-parse --verify --quiet "${MC}^{commit}" 2>/dev/null || true)"
      fi
      ;;
  esac
fi
[ -n "$TARGET" ] || fail_unknown "could not resolve '$ARG' to a commit (give a SHA/ref, or a PR number with gh available and the PR merged)"

# The merged commit MUST be reachable from HEAD, or we would be testing a tree that does not contain
# it — a green there proves nothing about the merge. Fail closed on a mismatch.
if ! git merge-base --is-ancestor "$TARGET" HEAD 2>/dev/null; then
  fail_unknown "the merged commit ${TARGET} is not in HEAD's history — the working tree does not contain this merge; check out fresh main before verifying"
fi

HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
BASE="${MAIN_BRANCH:-main}"
echo "post-merge-verify: verifying main is green after merge ${TARGET} (HEAD ${HEAD_SHA}, base ${BASE})"

# --- Resolve the project test command ----------------------------------------------------------
# The same "resolve + run the project test command → green/red/unknown, fail-closed" primitive the
# wai-learning-gap red-probe uses (own file, shared shape). $TEST_CMD is the explicit override; auto-
# detection covers the common ecosystems and is deliberately conservative — it only names a command
# when it can also see that a test target exists, so it never picks a command that would error with
# "no such script/target" and be mistaken for a red.
TCMD=""; TTOOL=""
if [ -n "${TEST_CMD:-}" ]; then
  TCMD="$TEST_CMD"; TTOOL="${TEST_CMD%% *}"
elif [ -f package.json ] && grep -q '"test"[[:space:]]*:' package.json; then
  if   [ -f pnpm-lock.yaml ]; then TCMD="pnpm test"; TTOOL="pnpm"
  elif [ -f yarn.lock ];      then TCMD="yarn test"; TTOOL="yarn"
  else                             TCMD="npm test";  TTOOL="npm"; fi
elif [ -f Cargo.toml ]; then TCMD="cargo test"; TTOOL="cargo"
elif [ -f go.mod ];     then TCMD="go test ./..."; TTOOL="go"
elif [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f setup.cfg ] || [ -d tests ]; then
  TCMD="pytest -q"; TTOOL="pytest"
elif [ -f gradlew ]; then TCMD="./gradlew test"; TTOOL="./gradlew"
elif { [ -f build.gradle ] || [ -f build.gradle.kts ]; } && command -v gradle >/dev/null 2>&1; then
  TCMD="gradle test"; TTOOL="gradle"
elif [ -f Makefile ] && grep -qE '^test:' Makefile; then TCMD="make test"; TTOOL="make"
fi

[ -n "$TCMD" ] || fail_unknown "no project test command could be resolved — set TEST_CMD to the repo's test command so the barrier can verify green"

# The tool must actually be present. Detecting a Cargo.toml does not mean cargo is installed; running
# an absent tool would fail non-zero and be mistaken for a red. A missing tool is UNKNOWN, not red.
case "$TTOOL" in
  ./*) [ -x "$TTOOL" ] || fail_unknown "test runner '$TTOOL' is not executable" ;;
  *)   command -v "$TTOOL" >/dev/null 2>&1 || fail_unknown "test runner '$TTOOL' is not on PATH (cannot run: $TCMD)" ;;
esac

# --- Run it ------------------------------------------------------------------------------------
echo "post-merge-verify: running project tests: $TCMD"
echo "---------------------------------------------------------------"
sh -c "$TCMD"
rc=$?
echo "---------------------------------------------------------------"

# pytest's exit 5 is "no tests were collected" — nothing was verified, so that is UNKNOWN (STOP),
# not a red. Every other non-zero from a tool that IS installed and DID run is a genuine failure.
if [ "$TTOOL" = "pytest" ] && [ "$rc" -eq 5 ]; then
  fail_unknown "pytest collected no tests (exit 5) — main was not actually verified"
fi

if [ "$rc" -eq 0 ]; then
  echo "VERDICT: GREEN — main is green after the merge. The barrier lifts; the next merge may proceed."
  exit 0
else
  echo "VERDICT: RED — '$TCMD' failed (exit $rc) after merge ${TARGET}. STOP the whole run: revert this"
  echo "         merge or flag it, then hand back with the autonomous-merge report. Do NOT start the next merge."
  exit 1
fi
