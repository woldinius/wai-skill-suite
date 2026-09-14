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
in one field run (issue #27), in capitals. The PRs were not unreachable; they were in a different repo than
the git side was asked about.

That is not cosmetic. The sweep is a good check and it catches a real class (a stacked PR merged
into a dead base, never arriving on the default branch). An alarm that is wrong 18 times in a
LEGITIMATE setup is skipped by the third run — and then it is absent the day it is right. The
false-positive rate is what keeps a finding alive; the same argument the gate's own record makes.

## Rows only in a worktree

The three append-only books — gate ledger, run log, invocation log — are written with
`--show-toplevel`, deliberately: a row belongs to the worktree that produced it. In a linked
worktree that means the row lands in *that* worktree's `docs/architecture/`, and reaches the
default branch only with that branch's PR. That is the right home under "a row rides the PR" (the
worktree's branch *is* the PR), and the writers were never the problem.

A field repo lost 11 run-log rows and 16 invocation-log rows anyway (field report of 2026-08-31,
§ 6e–6f): its PR assembly copied the three files from the **main checkout** over the worktree's
copies, and the rows a hook had written there were gone before anyone knew they existed. The
report asked for `--git-common-dir` — one shared file per repository. Measured here, that switch
is not free: in a linked worktree `--git-common-dir` is absolute, in the main checkout it is the
relative `.git`, so a naive swap re-opens the cwd defect of 2026-08-18 (a row planted wherever the
caller stood), and consolidating across worktrees changes *where state lands* — the contested half
of the ledger-home question, which #66 settled the other way. The loss happened in the copy step.
What was missing was **visibility** (#68).

So this script derives it, in the footer every hand-back pastes: for every worktree `git worktree
list` knows — this one included — the rows in its three books that are not on the base ref, per
book, with counts (`rows only in a worktree (not on origin/main …): <worktree path>: gate-ledger
+1`). Rows are compared on their first three cells (when, PR, verdict), so a row the human *tagged*
or whose reason was edited on the base is not reported as new. Rows are counted, not matched as a set: two identical rows in a worktree against one on the base are one row only in the worktree (a set comparison once printed *none* there). What stays undetectable is a row identical in text to a different event's row already on the base — the row format carries no id. Fail-open in the script's usual
shape: no base ref, or no worktree listed → *not checked*, named in the summary, never *none*. Each
writer's header now says in one sentence where its row lands in a linked worktree and names its
override (`MERGE_GATE_LEDGER`, `RUN_LOG`, `INVOCATION_LOG`); `doctor.sh` says so once, in a linked
worktree only; and `invocation-log.sh --snippet` says *why* the opt-in is repo-local, names the gap
that comes with it — an untracked settings file exists only in the checkout where it was written,
so a linked worktree runs no hook, which is how the same field repo counted about a fifth of its
invocations until it moved the hook to `~/.claude/settings.json` on 2026-09-03 — and says when that
global hook is the better choice. A repo that wants one consolidated ledger has a named path — the
overrides — instead of a copy step nobody watches.
