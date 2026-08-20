# `verify-arrival.sh` — why it is written this way

> The incidents behind the script's rules, kept here so the script carries the rule at the line
> and the narrative is citable without being billed to a context window on every run. Same split
> as every other file in this directory.

## A merged PR can arrive nowhere (field report 2026-08-06, issue #51)

A stacked set of four PRs (#131 → #132 → #133 → #134), each based on its predecessor's branch.
Merging bottom-up, the operator retargeted #132 and #133 onto `main` as their bases merged away —
not #134. GitHub then dutifully merged #134 into its stale base: a branch that had itself long
since merged and was a dead siding. The squash commit exists, the PR shows **MERGED**, the label
is purple — and `main` never saw it.

Every signal was green. CI checks the PR, not its destination; the merge gate had said GO (it
judges the diff, not where it flows); the tracker was silent (`Closes #N` fires only on a merge
into the default branch, so the issue simply stayed open — and nobody read "open" as a warning);
and the closing report said "#134 merged", because `gh pr view` said so. It was found the next
day, by accident, while recounting test assertions: 501 instead of 530.
([Field report](../field-reports/2026-08-06-merged-but-not-on-main.md).)

## The same class, at home: a four-commit batch on a squash-merged branch

The class reproduced in the suite's own origin repo within days: a four-commit batch was pushed
to a branch whose PR was already squash-merged. The push **succeeded** — a push to a dead branch
is a perfectly legal git operation — the commits landed on a siding, reached nobody's `main`, and
`main` stayed green, because everything that *was* there was correct. Nothing looks like
something that is missing. That incident (the third of its kind) bought the `.githooks/pre-push`
guard, which refuses a push to a branch whose PR is MERGED — the **push side** of the class.

`verify-arrival.sh` is the **merge side** of the same class: after any merge a skill performed,
the one question no earlier stage asks — is the merge commit reachable from the freshly fetched
default branch? The mechanics existed before the script did (the batch verifier and the
hand-back footer both run `git merge-base --is-ancestor`); what was missing was the wiring into
the paths that report success. The stage that knows the target state must tell someone.

## Why it fetches first, and why exit 2 exists

The ancestry test is only as fresh as `origin/<default>`. A stale remote-tracking ref answers
about yesterday's repository — it can call a commit LOST that arrived an hour ago, or worse,
ARRIVED against a default branch that has since been rewritten. So the branch is fetched before
the test, and a failed fetch is exit 2, not a shrug: this is a verifier, and "could not verify"
must never print as arrived. The same fail-closed shape as `post-merge-verify.sh`, whose barrier
comment carries the argument in full.

## Why it does not self-log

`run-log.sh`'s two-tier rule: a script appends its own attendance row only when its script↔skill
mapping is 1:1 and running it marks a real skill run. This one is an extractor invoked from at
least two skills (`wai-pr-review` after a solo merge, `wai-team` in the merge queue) and from the
shell when a human gets suspicious — a row from it would attribute one run to several skills, and
a wrong row is worse than a missing one: it is a datum someone will count.
