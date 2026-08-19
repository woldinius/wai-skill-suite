# `open-items.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## Self-recall under-reports, and MERGED is not arrived (issue #7)

Issue #7, measured twice in the field: self-recall under-reports ~3× — a long session
retrospected from memory reported 2 of 6 verified failures, and described one of the missed ones
as handled. And "MERGED" is not "arrived": a four-commit batch landed on a branch whose PR was
already merged; GitHub said MERGED, the default branch never saw it, and it was found a day later
by accident. A footer the model writes from memory inherits exactly that bias, in the comfortable
direction: an empty list reads as coverage. That is why the script emits and the model pastes.

Each of the three rules in the script's header (an empty line names its derivation; a skipped
class is named in the summary; per-line degradation) was a measured failure without it.

The ADR-0002 boundary is stated up front in the script because a script that decided "what to do
next" would be exactly the class this repo has deleted twice.

## Eighteen false alarms: gh and git answered about different repositories

This script used to take the git side's base from a fixed candidate list (origin/HEAD,
origin/main, …) while `gh` followed `gh repo set-default`. With ONE remote those agree, which is
why it shipped. With TWO they do not: a checkout whose work lives on a second remote while
`origin` points elsewhere had EVERY merged PR reported "MERGED BUT UNREACHABLE" — 18 false alarms
in one field run, in capitals. The PRs were not unreachable; they were in a different repo than
the git side was asked about.

That is not cosmetic. The sweep is a good check and it catches a real class (a stacked PR merged
into a dead base, never arriving on the default branch). An alarm that is wrong 18 times in a
LEGITIMATE setup is skipped by the third run — and then it is absent the day it is right. The
false-positive rate is what keeps a finding alive; the same argument the gate's own record makes.
