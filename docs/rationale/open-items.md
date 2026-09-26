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

This script used to take the git side's base from a fixed candidate list (origin/HEAD, origin/main,
…) while `gh` followed `gh repo set-default`. With ONE remote those agree, which is why it shipped.
With TWO they do not: a checkout whose work lives on a second remote while `origin` points
elsewhere had EVERY merged PR reported "MERGED BUT UNREACHABLE" — 18 false alarms in one field run
(issue #27), in capitals. The PRs were not unreachable; they were in a different repo than the git
side was asked about.

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
or whose reason was edited on the base is not reported as new. Rows are counted, not matched as a
set: two identical rows in a worktree against one on the base are one row only in the worktree (a
set comparison once printed *none* there). What stays undetectable is a worktree row whose compared
cells equal those of a different event's row that reached the base after the worktree's branch was
cut — the row format carries no id. Fail-open in the script's usual shape: no base ref, or no
worktree listed → *not checked*, named in the summary, never *none*. Each writer's header now says
in one sentence where its row lands in a linked worktree and names its override
(`MERGE_GATE_LEDGER`, `RUN_LOG`, `INVOCATION_LOG`); `doctor.sh` says so once, in a linked worktree
only; and `invocation-log.sh --snippet` says *why* the opt-in is repo-local, names the gap that
comes with it — an untracked settings file exists only in the checkout where it was written, so a
linked worktree runs no hook, which is how the same field repo counted about a fifth of its
invocations until it moved the hook to `~/.claude/settings.json` on 2026-09-03 — and says when that
global hook is the better choice. A repo that wants one consolidated ledger has a named path — the
overrides — instead of a copy step nobody watches.

## --brief: the footer names only what needs reading

Added 2026-09-26, with the lean-output change. The full footer is fourteen lines, and on a quiet
repo nearly all of its class lines say *none*. Pasted at the end of every hand-back, it was often
the longest part of one, and the lines that mattered (an open PR, an untagged ledger row) sat
among the ones that did not. The operational output around it had grown too: PR body median
5,033 characters · review comment median 4,491 · comments per PR median 8,639 — measured
2026-09-26 over the merged/open PRs among #56–#85 with `gh pr view <n> --json body` and
`gh api repos/woldinius/wai-skill-suite/issues/<n>/comments`; review comment = a body starting
`## PR Review`; medians over the PRs that have comments. The population grows with every new
comment, which is why the date is part of the figure. The footer was one of the fixed costs in
that output.

`--brief` prints only the classes with a finding, then one line:
`open items — clean: 6 of 8 classes · skipped (no artifact): audits · not derived: asked, unanswered`. Three
rules keep that brevity from becoming the bias the script exists to remove:

- **A not-checked class always prints.** A check that could not run is itself a finding; dropping
  it would turn "gh was down" into a line that reads like coverage.
- **A "none" with a caveat is not clean.** A sweep that could not verify a merge commit (not
  local), or a base that may belong to a different repository (several remotes, not resolved
  from gh), prints its line and is not counted in `clean: N`. A "none" against a base resolved
  from gh is clean, and its informational note drops with it.
- **The summary still names what was skipped and what is never derived.** The three trust rules
  of the default output hold; only the lines that say *none* go.

The default output is unchanged, and so are the exit codes. Writing the one-line test for this
mode exposed a defect in both modes: in a repo without a remote, `grep -c . || echo 0` printed
`0` twice and `[` wrote an error into the footer. It was stderr noise, never a wrong answer, and
it is `|| true` now.