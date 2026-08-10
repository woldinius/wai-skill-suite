# Publication — drafts

What we intend to say, outward. **Drafts until they ship**, and therefore *undated*: a date here would
invite the reader to mistake a draft for a record. It gets one when it is published.

Everything in this directory must be able to point at something in [`../learnings/`](../learnings/) or
[`../empirics.md`](../empirics.md). **A claim that cannot be traced to a measurement does not go out** —
we have already shipped one that could not (*"for a year…"*, in a blog draft, in social posts, in a PR
body, and in the source of `catalog-lint.sh` itself; the repo is one month old).

| | |
|---|---|
| [`blog-the-check-that-never-ran.md`](blog-the-check-that-never-ran.md) | 55 of 89 dimensions had no Red Flag, and nothing checked |
| [`social-the-check-that-never-ran.md`](social-the-check-that-never-ran.md) | short forms of the same |

**Planned, not written** (see the project notes): a *Lessons Learned* built from the field runs — with
the cons as the material, not an appendix — and a separate piece on the sources the suite was designed
against, whose most interesting half is the two **negative** results.

## Before anything is posted

`empirical-test-plan.md` exists because **the central claim of these drafts is not yet established.**
Test 0 in that plan can falsify it: if the model turns out to ignore the script and check from memory
anyway, the "determinism" framing is wrong and the drafts need rewriting. **Run it first.**
