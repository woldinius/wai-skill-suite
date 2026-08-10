# FEEDBACK: `Closes #N` only closes on a merge into the DEFAULT branch

> Translated from the German original; the original remains in the private archive. The product
> repo is anonymized (a game-server prototype).

**(Reconstruction. The first version was written 2026-08-02 and lost with `temp/` — see
[`2026-08-02-suite-channel-loss-unread-feedback.md`](2026-08-02-suite-channel-loss-unread-feedback.md).
The reported state is unchanged: "default branch" appears nowhere in `wai-pr-review`, `wai-team`
or `issues-protocol.md`.)**

**Context:** a `wai-team` run in the game-server prototype. Three PRs with correct
`Closes #N` keywords in the body, cleanly merged to `main`, the code demonstrably on `main`.
**All four referenced issues stayed OPEN regardless.**

## Cause
The repo's **default branch** was accidentally an old feature branch (`agent/<handle>/feature-…`),
not `main`. GitHub processes the closing keywords (`Closes`/`Fixes`/`Resolves #N`) **exclusively
on a merge into the default branch**. Merge into `main` (≠ default) → the keywords never fire →
the issues stay open.

The human read "issue open" as "not integrated" and asked what had gone wrong with the team run —
although everything had been correctly built, tested and merged. **Trust damage out of a repo
setting no skill checks.**

## Proposals (git protocol / pr-review / wai-team)
1. **Check the precondition once** (cheap, once per repo/run):
   `gh repo view --json defaultBranchRef` → if default ≠ merge target, **flag loudly** before
   relying on `Closes #N`.
   *Fix hint, with its own trap:* `gh repo edit --default-branch main` returned **exit 0 but did
   not take effect**. Only
   `gh api -X PATCH repos/OWNER/REPO -f default_branch=main` worked reliably. Recommend the API
   variant.
2. **After the merge, verify the issue is actually CLOSED** — do not assume it from "PR merged".
   If not → cause is the default branch, else close manually with a PR reference.
3. **Honest team report:** "PR merged" ≠ "issue closed". The report should state issue status
   separately, or exactly this misunderstanding arises.

## Retroactively
A later default-branch change does **not** retroactively close already-merged PRs — the affected
issues must be closed by hand.

## Related
[`2026-08-02-prototype-review-verdict-not-on-pr.md`](2026-08-02-prototype-review-verdict-not-on-pr.md)
— the same class: **the skill believed it had achieved something without checking it in the
system.**
