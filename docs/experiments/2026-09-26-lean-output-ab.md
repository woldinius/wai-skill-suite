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
  installed with its own `install.sh`), one fresh agent, the same model, the prompt below with only
  the path changed. Local only: no GitHub, so the gate returns UNKNOWN.
- **Two runs per arm (n = 2).** The sandboxes were deleted after this report was reviewed.

**Metrics.** *Review:* words in the review file the run wrote (it stands in for the PR comment).
*Hand-back:* words in the agent's final report. *Commit messages:* characters of
`git log main..<branch> --format=%B`. *Plan:* words in `docs/planning/**/*.md`. *Tokens and
responses:* `session-cost.sh` on the agent's transcript (one response per request id, at its
largest output count).

<details><summary>The prompt (identical for all four runs, path removed)</summary>

```
Build a small piece of software in the git repo at <sandbox> using the wAI skill suite installed
in that repo. Rules: work only inside that repo; use the suite by READING each skill's
instructions from .claude/skills/<skill>/SKILL.md inside that repo (no Skill tool, no subagents);
local only — no GitHub, no gh, no push, no network, and where a skill step needs GitHub, skip it
and say so in one line; no questions to the user — decide sensibly and state the assumption.
The software: inventory, a Python 3 command-line tool and library, standard library only, that
tracks stock items — add <name> <qty>, remove <name> <qty>, list, and low --threshold N — persisted
as a JSON file, with unit tests run by python3 -m unittest.
Lifecycle, each step begun with a plain-text line [[STEP <name>]]: plan (wai-requirements-planning)
· implement (wai-implementation, branch agent/sandbox/feat-inventory) · test (wai-testing) ·
review (wai-pr-review: review the branch against main as if it were the PR, write it to review.md,
run the scripts the skill names where they run locally) · handback (the final message, as the
skills instruct).
```
</details>

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
- **Token totals did not fall.** Output −1 % and cache reads +13 % (all tokens +12 %) — both inside
  the spread: the two runs of one arm differ by about 17 %. The visible text saved is about 20 k
  characters a run (≈ 6 k tokens, 3 % of output, a characters ÷ 3.6 estimate); the rest of the
  output is reasoning.
- **Turns moved the other way.** Every B run took more responses than every A run (61, 66 vs 47,
  53). Whether the output rules cost turns is open; on the means, cache reads follow responses.
- **Quality held on this task.** All four runs ended green; every run counterproofed its tests
  (50 · 49 · 45 · 78 deliberate breaks, all caught); every review reproduced a real defect — a
  save that exits 1 after writing, so a retry applies twice (A1, `RES-3`); two Unicode spellings of
  one name splitting its stock (A2, B1, `MAINT-9`); a read-only file rewritten anyway (B2,
  `MAINT-9`).

**What follows.** The lean changes did their job for the reader and did not lower the token bill.
Reasoning effort and turn count are the cost levers still to measure.

**Limits.** n = 2 per arm, one small task; each run wrote its own code, so the review findings
differ; same model throughout; no GitHub (gate UNKNOWN, `wai-init` skipped — the catalog was
seeded); no split by lifecycle step (the step markers reached visible text inconsistently, 9 of
20 times).

**Found on the way** (filed): two suite defects, #88 · #89, and three gaps, #90 · #91 · #92.
