#!/usr/bin/env sh
# verify-gap-breaks.sh — a planted gap that does NOT go red is a gap that teaches nothing.
#
# The whole mechanism rests on one promise: after a gap is planted, build/tests go RED, so the
# human KNOWS a line is missing and has something concrete to restore. A gap that leaves the tree
# green is worse than no gap — the human never notices it, the marker rides along into the next
# commit unseen, and the Leitner box gets promoted for an exercise nobody did. The skill used to
# assert "the gap must fail visibly" in prose and hope the model checked. "The model checked" is
# not auditable. This is: it RUNS the project's own test command and reads the exit code.
#
# The one subtlety, and the reason this is not just `! test`: the Socratic architecture gap
# (see references/axes.md) is a NON-removal form. It asks the human to explain a structural choice;
# it removes no code, so the tree stays green ON PURPOSE. Running the red-probe against it would
# wrongly reject a legitimate gap — so for `--form socratic` this script does not run anything at
# all, it says N/A and returns success. Only cloze and structural gaps must go red.
#
#   exit 0  the gap breaks visibly as intended (test went RED) — OR the form is socratic (N/A)
#   exit 1  the tree is STILL GREEN — the removed line failed silently; replant it somewhere it bites
#   exit 2  the test command could not be run at all (UNKNOWN) — fail closed, never call this a pass
#
# What this does NOT decide: whether the gap is pedagogically good; the FORM (the model passes it);
# whether a green Socratic gap is legitimate (it is skipped, not failed — a different thing).
#
# Usage:  sh verify-gap-breaks.sh --form cloze|structural|socratic [test-command ...]
#   e.g.  sh verify-gap-breaks.sh --form cloze npm test
#         sh verify-gap-breaks.sh --form structural ./gradlew test
#         sh verify-gap-breaks.sh --form socratic        (returns 0, runs nothing)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

FORM=""
# Parse ONLY the leading --form flag; everything after it is the verbatim test command.
if [ "${1:-}" = "--form" ]; then
  FORM="${2:-}"
  shift 2 2>/dev/null || { echo "verify-gap-breaks: --form needs a value (cloze|structural|socratic)" >&2; exit 2; }
else
  echo "verify-gap-breaks: first argument must be --form cloze|structural|socratic" >&2
  exit 2
fi

case "$FORM" in
  socratic)
    # A Socratic gap stays green by design — there is nothing to break. Do NOT run the probe.
    echo "verify-gap-breaks: form=socratic — the tree stays green by design; the red-probe is N/A (skipped)."
    exit 0
    ;;
  cloze|structural)
    : ;;
  *)
    echo "verify-gap-breaks: unknown --form '$FORM' (expected cloze|structural|socratic)" >&2
    exit 2
    ;;
esac

# A cloze/structural gap MUST make the tree red. That needs a command to run.
if [ "$#" -eq 0 ]; then
  echo "verify-gap-breaks: no test command given for a $FORM gap — cannot verify it breaks (UNKNOWN)." >&2
  echo "  Pass the project's test command, e.g.  --form $FORM npm test" >&2
  exit 2
fi

# Resolve the command before running it, so a missing binary reads as UNKNOWN (2), never as RED (0).
# `red` (the gap works) and `could-not-run` (we learned nothing) are different states and the whole
# point of the fail-closed rule is not to conflate them.
if ! command -v "$1" >/dev/null 2>&1; then
  echo "verify-gap-breaks: test command '$1' not found on PATH — cannot verify (UNKNOWN)." >&2
  exit 2
fi

# Run it. We care ONLY about the exit code; capture its output so it does not muddy this verdict.
OUT="$("$@" 2>&1)"; rc=$?

case "$rc" in
  0)
    echo "verify-gap-breaks: form=$FORM — the test command PASSED (tree still green)."
    echo "  The removed line succeeded silently: nothing forces the human to restore it. Replant the"
    echo "  gap on a line whose absence breaks the build or a covered test (see references/axes.md)."
    exit 1
    ;;
  126|127)
    # 126 = found but not executable, 127 = not found from within the command's own resolution.
    echo "verify-gap-breaks: the test command could not execute (exit $rc) — cannot verify (UNKNOWN)." >&2
    printf '%s\n' "$OUT" | sed 's/^/  | /' >&2
    exit 2
    ;;
  *)
    echo "verify-gap-breaks: form=$FORM — the test command FAILED (exit $rc): the gap breaks visibly. Valid."
    exit 0
    ;;
esac
