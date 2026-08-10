# GAP: a PR can be "merged" and still arrive nowhere — nothing in the suite checks that

**Source:** a hobby game-server repo (`solo` mode) — the same field repo as
[the 30-run report](2026-08-06-thirty-runs-zero-false-negatives.md); suite version `819923d`
**Date:** 2026-08-06
**Severity: high** — no crash, no red signal. For one night, finished, tested work was missing
from the product while GitHub, the tracker and the run report all said "done".
*(Translated; the German original is in the private archive.)*

## What happened

A stacked set of four PRs (#131 → #132 → #133 → #134), each based on its predecessor's branch.
Merging bottom-up, I retargeted #132 and #133 onto `main` as their respective bases merged away —
**not #134.**

GitHub then dutifully merged #134 into its stale base branch: a branch that had itself long since
merged into `main` and was a dead siding. The squash commit exists, the PR shows **MERGED**, the
label is purple — and `main` never saw it.

```
$ git merge-base --is-ancestor d66107f origin/main ; echo $?
1                                   # not contained
```

I noticed the next day, while recounting test assertions: **501 instead of 530.** Without that
coincidence it would have stayed unnoticed, because:

- **CI** was green (it checks the PR, not its destination),
- the **merge gate** had said GO (it checks the diff, not where it flows),
- the **tracker** was silent (GitHub honours `Closes #96` only on a merge into the default
  branch — a lucky accident that even *masked* the gap: the issue stayed open, but nobody read
  that as a warning),
- and **my own closing report** said "#134 merged", because `gh pr view` said so.

## Why the suite does not catch it

`merge-gate.sh` answers the question *"may this diff be merged?"* — catalog, repo mode, checks,
excluded domains. All four are properties of the **content**.

The question *"did it arrive where it was supposed to?"* is asked by nobody. It has to be asked
after the merge, and the suite has no place for "after the merge" — `post-merge-verify.sh` in
`wai-team` runs only in batch mode and checks something else.

This is not a weakness of the script but an **open spot in the chain**: the only stage that knows
the destination state is the one that tells nobody.

## Proposal

**1 — A post-check that need not cost more than two lines.**

```sh
# For every recently merged PR: is its merge commit reachable from the default branch?
gh pr list --state merged --limit 20 --json number,mergeCommit,baseRefName \
  -q '.[] | "\(.number) \(.mergeCommit.oid) \(.baseRefName)"' |
while read -r nr sha base; do
  git merge-base --is-ancestor "$sha" origin/HEAD 2>/dev/null ||
    echo "PR #$nr is MERGED but not on the default branch (base was: $base)"
done
```

That would have raised the alarm the same night. As its own script
(`wai/scripts/merged-but-unreachable.sh`), called from `doctor.sh` — which already owns the
question "does the repo's state still match what the suite assumes?".

**2 — The actual cause sits one step earlier: stacked PRs.**

The base of a stacked PR is an **ephemeral** branch. GitHub retargets automatically when the base
merges into the default branch — but **not** when it merges into *another* branch, and not
reliably on squash merges. Whoever stacks must check, after every merge in the chain, whether the
next PR's base still exists.

`agent-git-protocol.md` does not describe the stacked PR. One paragraph would do:

> **Stacked PRs.** The base is the predecessor branch, not `main`. **After every merge in the
> chain, check the next PR's base and retarget it onto `main`** (`gh pr edit <N> --base main`)
> once its predecessor is in. A PR whose base has already merged and been deleted otherwise merges
> into a void: GitHub reports success, the default branch receives nothing.

**3 — And an observation about reporting.**

I reported "#134 merged" because the tool said so. The same pattern as the `git rebase | grep`
that swallowed a conflict, and the `sed -E` with `\b` that replaced nothing under BSD and returned
0: **the command ran, the effect was missing, and what got reported was the command.** For agents,
"exit code 0" is not the same as "the intended thing happened" — and a report that equates the two
is wrong exactly when it matters.

That is why proposal 1 belongs in a **script**, not a checklist: it is the one check an agent
cannot answer from memory.

## What I did in the repo itself

Recovered the orphaned commit through a new PR onto `main`, catching up review and gate on the way
(the code had never been reviewed — a second collateral of the same incident: it passed as
"merged", so nobody asked the question anymore).
