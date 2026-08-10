# DEFECT: wai-pr-review — the verdict landed only in the chat, not on the PR

> Translated from the German original; the original remains in the private archive. The product
> repo is anonymized (a game-server prototype).

**(Reconstruction. The first version was written 2026-08-02 and lost with `temp/` — see
[`2026-08-02-suite-channel-loss-unread-feedback.md`](2026-08-02-suite-channel-loss-unread-feedback.md).
The reported state is unchanged: `wai-pr-review/SKILL.md` names posting only in the `team` GO
branch and in the merge-denied branch.)**

**Date:** 2026-08-02 · **Repo:** the game-server prototype · **PR:** the new-world consensus PR
**Reported by the human:** "The PR-review skill's feedback is nowhere to be found on the PR on
GitHub."

## What happened
The complete review (classification, lens, findings, positives, gate result) was emitted in the
**chat** and posted **nowhere** on the PR. On GitHub the PR carried only a `wai-testing` comment.
**The human noticed it, not the skill.**

**Consequence:** the review existed only in an ephemeral session. Whoever looks at the PR later —
or is supposed to approve in `team` mode — sees no reasoning, no gate result, no findings.

## Why it could happen (a skill gap, not just an execution error)
Step 6 says "Post the verdict as a PR comment" **only** in the `team` branch, and there in the
context of the **GO** path (post verdict + arm auto-merge), plus in the "merge denied" case. For
the **NO-GO / UNKNOWN** path it says only: *"The human merges. Quote the reasons."* — **"quote"
where?** The chat is the obvious, wrong reading. The *Output format* section says "Use exactly
this structure", but **not where** the structure goes.

Result: precisely on the path where the human needs the review most urgently (gate red → **he**
must decide), the posting is weakest specified.

## Proposal
1. **The verdict ALWAYS belongs on the PR — on every path** (GO, NO-GO, UNKNOWN, Blocker/Major,
   contract-domain, merge-denied). Wording e.g.: *"Post the review as a PR comment as the first
   action of step 6; the chat output is a copy for the human, never the primary artefact."*
2. **Fix the order:** post review → append gate result → then merge/hand-off. Today the posting
   hangs off the merge branch and is skipped when nothing merges.
3. **Make it explicit in the `Output format` block:** "Destination: PR comment
   (`gh pr comment`) + a short form in the chat" — analogous to how `wai-requirements-planning`
   writes back to the issue.
4. **Self-check at the end:** "Verify the verdict is visible on the PR
   (`gh pr view --comments`)."

## Related
Same class as
[`2026-08-02-prototype-closes-needs-default-branch.md`](2026-08-02-prototype-closes-needs-default-branch.md)
(the merge ran, the issue stayed open) and as the loss of this very file: **a result in the
head/chat ≠ a result in the system.** A generic "did it actually reach the system?" check at the
end of every skill would be the shared answer to all three.

## Fixed (in the incident)
The review was posted to the PR retroactively.
