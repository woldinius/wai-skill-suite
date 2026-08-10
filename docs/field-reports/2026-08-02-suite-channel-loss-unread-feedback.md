# ⚠️ Read first: this channel (`temp/input/`) loses feedback

> Translated from the German original; the original remains in the private archive.

**Incident, 2026-08-02.** Two feedback files were dropped here and were **gone without a trace**
a few hours later — `temp/input/` no longer existed:

- the default-branch feedback (now reconstructed as
  [`2026-08-02-prototype-closes-needs-default-branch.md`](2026-08-02-prototype-closes-needs-default-branch.md))
- the review-verdict defect (now reconstructed as
  [`2026-08-02-prototype-review-verdict-not-on-pr.md`](2026-08-02-prototype-review-verdict-not-on-pr.md))

**How it happened:** a session in the skills repo processed the *earlier* feedback (the
"combine the building blocks" batch) and then cleaned up `temp/`. `temp/**` is in `.gitignore`,
so the files were **never versioned**: no commit, no history, no restoring. The two files dropped
later went down with it, **before** they were read. Proof: the behaviour they reported was still
unchanged in the skills (see the two reconstructed files next to this one).

**Why this hurts in particular:** the content of one of the lost files was exactly the rule
*"a result that is not in the system did not happen"*. The channel refuted its own message.

## Proposal: a durable channel instead of a temp folder

The repo has a GitHub remote and its commits already reference issues. **Feedback belongs there**,
not in a gitignored folder:

- **One GitHub issue per learning** (label e.g. `skill-feedback`) — survives clean-ups, is
  findable, has a status, and a commit can point at it with `Closes #N`.
- If the temp folder is to stay as an inbox: **before any clean-up**, convert its content into
  issues — and exempt `temp/input/` from `.gitignore` (`!temp/input/`), so unread feedback at
  least shows up in `git status`.

Until that is decided, the reconstructed files sit here again — with the same risk.
