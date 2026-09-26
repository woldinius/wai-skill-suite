# Lean output, measured — a controlled A/B in throwaway sandboxes (2026-09-26)

**Question.** Did the lean-output changes of [#86](https://github.com/woldinius/wai-skill-suite/pull/86)
(brief footer, one review copy, size budgets, hand-back shape, fix-loop rules) cut what a
lifecycle run writes, and what it costs?

## Method

- **Two arms.** A = the suite at `92948c0` (before #86) · B = `c4d42f6` (after #86 and #87).
- **One task.** Build `inventory`: a small standard-library Python CLI and library (`add`,
  `remove`, `list`, `low --threshold N`, JSON persistence, `unittest`), through plan → implement →
  test → review → hand-back, following the skill files installed in the sandbox.
- **Per run:** a fresh sandbox repo (the `minimum` catalog variant copied in, the arm's suite
  installed with its own `install.sh`), one fresh agent, the same model, an identical prompt except
  the path. Local only: no GitHub, so the gate returns UNKNOWN.
- **Two runs per arm (n = 2).** Tokens from each agent's transcript via `session-cost.sh`; artifact
  sizes from the sandbox. The sandboxes were deleted afterwards.

## Results

| Metric | A1 | A2 | B1 | B2 | mean A | mean B | Δ |
|---|---:|---:|---:|---:|---:|---:|---:|
| Review (words) | 2,432 | 1,371 | 774 | 588 | 1,902 | 681 | **−64 %** |
| Hand-back (words) | 1,367 | 1,607 | 371 | 568 | 1,487 | 470 | **−68 %** |
| Commit messages (chars) | 4,230 | 2,667 | 3,039 | 2,611 | 3,449 | 2,825 | −18 % |
| Plan (words) | 1,920 | 1,639 | 1,862 | 1,989 | 1,780 | 1,926 | +8 % |
| Responses | 53 | 47 | 61 | 66 | 50 | 64 | +27 % |
| Output tokens | 207,117 | 174,989 | 173,931 | 204,556 | 191,053 | 189,244 | −1 % |
| Fresh input tokens | 412,043 | 338,967 | 317,536 | 346,908 | 375,505 | 332,222 | −12 % |
| Cache-read tokens | 13.5 M | 10.1 M | 12.1 M | 14.6 M | 11.8 M | 13.3 M | +13 % |
| Tests green | yes | yes | yes | yes | | | |

## Reading

- **What a human reads fell sharply and consistently.** Every B run is below every A run on both
  the review and the hand-back; the difference is larger than the spread between runs.
- **Total tokens did not move.** Output −1 % is far inside the spread: the two runs of one arm differ by about 17 %; cache
  reads rose with the number of responses. Visible text is about a fifth of the output tokens (a
  characters ÷ 3.6 estimate); the rest is reasoning. Shorter artifacts cannot move a total they are
  a fifth of.
- **Quality held on this task.** All four runs ended green; every run counterproofed its tests
  (45–78 deliberate breaks, all caught); every review found real defects.

**What follows.** The lean changes did their job for the reader. Cost is driven by reasoning and by
the number of turns — neither is touched by output rules, and both need their own measurement.

**Limits.** n = 2 per arm, one small task; each run wrote its own code, so the review findings
differ; same model throughout; no GitHub (gate UNKNOWN, `wai-init` skipped — the catalog was
seeded); a split by lifecycle step was not measurable (step markers rarely reached visible text).

**Suite defects the runs found independently** (filed): #88 · #89 · #90 · #91 · #92.
