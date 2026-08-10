# 2026-08-05 · suite · The second review, and what the first fix batch got wrong about itself

**Source:** the suite repo itself — a second cold review, run after the seven-commit fix batch
(PR #12) landed on `main`.
**Corrects:** two cells of
[`2026-08-05-first-checkout-review.md`](2026-08-05-first-checkout-review.md). Per the append-only
rule, that report is not edited; this entry points at it.

## What the second review found

The fix batch closed all three blockers, and the tests it added are real — re-run against the
pre-fix installer, the new install test goes red. That part held. What did not hold is the batch's
**reporting about itself**, and the pattern is the one this repo keeps writing down: claims with no
check behind them, shipped alongside fixes for claims with no check behind them.

### 1 · M4 was recorded as Fixed. It was half-done — and the record said otherwise.

The unbacked "94% more expensive" figure was removed from the social draft only. The blog draft
carried it in the same line it always had (`docs/publication/blog-the-check-that-never-ran.md`,
"What this is not" section) — verifiable with `git show 819923d:… | grep 94%`. Two records then
compounded it:

- the commit message of `fa49324` stated *"The blog draft never carried it"* — false, and checkable
  against the very history the message ships in;
- the first-checkout report's outcome table marked M4 **Fixed**.

A wrong outcome cell is worse than an open finding: an open finding gets picked up, a "Fixed" gets
skipped by every later reader. The figure is now removed from the blog draft too, with the same
wording ADR-0001 uses for it (the percentages are not preserved; publishing a number that cannot be
shown is the failure the post is about).

### 2 · M1 "eight → nine skills, counted" was recorded as Fixed at 2 of 5 sites.

The catalog-reader count was corrected in `quality-attributes.md` and the baseline — and left at
"eight" in `catalog-lint.sh`, `setup-report.md` and `catalog-sizing.md` (which names the readers
and named eight). The partial fix produced something the uniform error never was: two answers to
the same question in one repo. All sites now say nine, and the sizing document names the ninth
(`wai-mobile-release`).

### 3 · The batch minted three new unbacked numbers while fixing the old ones

- **`v0.1.1` did not exist.** Both documented install paths — the pinned clone and the pinned
  curl-pipe — pointed at a tag that was never cut (`git tag` listed only `v0.1.0`). A cold reader
  following the README got "Remote branch not found" and a 404: the same failure class as B1,
  introduced by the commit that fixed B1. The README now pipes from `main` and says why (`v0.1.0`
  predates the installer fix); the pinned examples show a placeholder until a tag exists.
- **"nine reports"** went stale in the same batch that added the tenth report. The count is gone
  from the README — it went stale twice in two days, and the directory listing is the number.
- **"six field runs"** in the learnings index, against eight runs in `empirics.md`. Now eight.

### 4 · Two checks that could lie about themselves

- The new YAML-frontmatter guard reported its own absence as a pass: with no `python3`+PyYAML it
  printed a green `ok … SKIPPED` — in the test file whose header argues that a green check without
  coverage is the worst kind of green. Skips now have their own verb, their own counter, and a
  summary line that says *a skipped check is not a pass*.
- The gate ledger's first real row was amputated mid-token at 160 characters
  (`… 2 of 3 are not: test (ubuntu-`) by a silent `cut -c1-160` — a cut that reads exactly like a
  complete reason. The cell now caps at 400 characters on a word boundary with a visible `…`, and
  the row stays one line, because `gate-stats.sh` and the human outcome tag both key on
  one-row-per-verdict.

### 5 · Carried over, not new

`excluded-domains.sh` still accepted `--repo ""` and `--repo=` silently while `merge-gate.sh` had
just been fixed for exactly that hole — the two parsers had forked. Both now refuse an empty value
as a usage error (exit 2), with tests on both.

## The lesson, again

Every item above is the same finding as the first review's, one level up: **the fix batch had no
check on its own claims about the fix batch.** An outcome table, a commit message and a version
number are prose — and prose went stale within one day of being written. The two open proposals
this points at are already filed: a numbers lint (first-checkout report, item #7) and checks for
the publication layer (item #11). Until one exists, every count in this repo's prose is a claim,
not a fact.

---

## Addendum — appended 2026-08-05, after the merge. §4 above was itself half-wrong.

Per the append-only rule the text above stands unedited; this entry corrects it.

§4 describes the ledger truncation as fixed. The seam review after the merge found the same
`cut -c1-160` alive one level deeper in the same data path: `merge-gate.sh` capped the domain
classifier's summary (`EXCL_SUM`) at 160 characters before it ever reached the widened cell. So a
long NO-GO for an excluded domain would still have shipped amputated — and this report, a document
about half-done fixes being recorded as done, recorded a half-done fix as done. Third iteration of
the class, this time by the reviewer.

Both truncation sites now share one function (`cap400` in `merge-gate.sh`), so they cannot drift
apart again — and `tests/numbers-lint.sh` exists as of the same batch, which is the closest thing
prose claims in this repo have had to an exit code.
