# `retro-compliance.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The record measured side effects, not work

Issue #10, Part B, measured in the field: a skill left a trace ONLY if it filed something, so the
record measured the side effects of work, not the work. The run log (issue #11) is the fix — one
appended row per run — and this script exists because the run log's second writer tier is prose:
a SKILL.md sentence that nothing verifies. Crossing the run log against the gate ledger and the
merge history is where that prompt-contract weakness, pointed at the suite itself, becomes
visible instead of comfortable.

## The merge-commit denominator inverted the metric

`git log --merges` was the only enumerator of merged PRs — offline and deterministic, but it reads
merge COMMITS, and a squash- or rebase-merged PR leaves none. That inverted the metric's purpose
on any repo that squash-merges. On this repo PRs #1–#6 were merge-committed and everything since
#15 was squashed, so the live traced share (5/5 = 100%) covered only the era that PREDATES the
metric, and the very gap that motivated it (#15/#16 merged without gate verdicts) was invisible.
A denominator that silently excludes the population it was built to measure is worse than no
denominator. (#24) That is why the script now prefers `gh pr list --state merged` — which counts
a squash merge exactly like a merge commit — and names the degradation whenever it has to fall
back to merge commits.

## A 0% that was really 15%

The principle "every metric needs a counter-reader" was bought in the field: a 0% that was really
15% once shipped inside the very line meant to prove trustworthiness. That is why every rate this
script prints carries its raw counts beside it.
