# Open questions — the numbers this suite does not have yet

An external audit of this repository (2026-08-06, conducted cold against the tree and the GitHub
API) confirmed what the README's *Limits* paragraph says in prose — and turned it into a list of
measurements. This file is that list, kept as a **live eval agenda**: every row is a question the
suite cannot answer today, the measured state as of now, and the experiment that would answer it.

Two rules keep this file honest:

- **The ledger-derived numbers below are re-measured on every CI run** by
  [`tests/numbers-lint.sh`](../tests/numbers-lint.sh) against
  [`gate-ledger.md`](architecture/gate-ledger.md) (via `gate-stats.sh`, the one ledger authority).
  If the ledger moves and this file does not, CI goes red. A number nothing re-measures is a
  claim, not a fact.
- **A question leaves this file only with its answer linked** — a field report, a ledger extract,
  a measurement in the repo. Deleting a row without one is the failure mode this suite documents
  everywhere else: a check that quietly stopped running.

| # | Question | Today, measured | What would answer it |
|---|---|---|---|
| Q1 | Does the gate ever say GO in this repo — or is "fail-closed" where it has always been? | **43 gate verdicts on record, 7 GO rows** (PR #17, 2026-08-06; PR #1 and PR #4, 2026-08-11; PR #31, 2026-08-16; PR #45 twice and PR #47, 2026-08-19), **9 untagged**. A field repo reports 30 runs with GO 5 · NO-GO 22 · UNKNOWN 0 ([field report](field-reports/2026-08-06-thirty-runs-zero-false-negatives.md), dated), and 85 verdicts over its full three-week window ([2026-08-12 report](field-reports/2026-08-12-three-weeks-of-ledger.md), dated) | Answered for existence on 2026-08-06 — here and in a second repo; stays open as a rate until the ledger has enough GO rows to review weekly |
| Q2 | Does the model actually *run* the gate, or check from memory? (Test 0) | 1 documented field run (empirics, Run 1) + this repo's ledger; a field repo's ledger carries 82 human-tagged rows ([2026-08-12 report](field-reports/2026-08-12-three-weeks-of-ledger.md), dated); **bypass rate unmeasured** | ≥ 30 review runs; report the share with a matching ledger row. Below ~90 %, the determinism claim fails at the execution layer — and that gets published too |
| Q3 | How often is the gate wrong? | This repo: **28 judged NO-GOs, 0 fp**; **0 fn of 4 judged GO rows**; 34 of 34 rows tagged, with one `need inspection` outside every rate. The next column's threshold is **met** (2026-08-18) — and 0 % over 26 rows is this repo's rate, not the suite's: a field repo measures **fp = 8 of 52 judged NO-GOs = 15 %** over its full window (field repo fr-06287b7fb053, 2026-08-12, [field report](field-reports/2026-08-12-three-weeks-of-ledger.md), dated), having reported 12 judged NO-GOs with 0 fp and 0 fn over its first 30 runs ([field report](field-reports/2026-08-06-thirty-runs-zero-false-negatives.md), dated — its numbers age with it) | ≥ 20 human-tagged rows here — **met**; read with `gate-stats.sh`. What stays open is the same extract from a repo this author does not own (Q7): one author's 0 % and a field repo's 15 % are not the same measurement. One `fn` outweighs ten `fp` |
| Q4 | Are the three review lenses different, or decoration? | 2 lenses on 1 PR produced different finding classes (empirics, Run 2) — suggestive, not a test | 5 PRs × 3 lenses; diff the finding sets. Overlap > 80 % ⇒ delete the lenses |
| Q5 | What does a lifecycle run cost in context? | **Not measured.** Earlier token numbers are preserved nowhere (retrospective §1d) and are cited nowhere since | Tokens per run, split by SKILL.md / references / catalog; small-vs-full catalog tier on the same PRs |
| Q6 | Does `team` mode hold in the field? | **Zero field evidence** — every ledger row and field report to date says `solo` | One `team` repo, two accounts, one PR: verify `--auto` waits for the second human and the skill never approves |
| Q7 | Does the suite work outside its author's repos? | One author; eight field runs; all evidence repos share the author's product shape | ≥ 3 foreign repos with a pasted `gate-stats.sh` extract — see the field-report template |
| Q8 | Do the lifecycle skills run on other harnesses? | **Untested** (README, *Porting*) | One report of the catalog + protocols consumed by a non-Claude-Code agent |
| Q9 | Is the per-skill exposure table honest — which skills carry how much use? | The author's self-report only (README §Skills): five daily, two periodic, two less-often, two once-per-repo — plus the personal skill, daily by two developers; per-skill run counts exist nowhere | Field reports that name the skills they ran (the template asks); ≥ 3 foreign repos reporting per-skill usage |

Every row here is a number the author does not have. The repo contains the instruments that
produce them — `gate-stats.sh`, the append-only ledger, `numbers-lint.sh`. **If you use the
suite, you generate these numbers anyway; contributing one is a paste.**

## How to contribute a number

- Run `sh .claude/skills/wai-pr-review/scripts/gate-stats.sh` in your repo and paste the output
  into a field report (template: `docs/field-reports/`) or an issue.
- The most interesting report is the one where the suite was **wrong**: a NO-GO you merged
  unchanged (`fp`), or a GO you later judged should have been blocked (`fn`). The ledger has a
  column for both; §Q3 is waiting for them.
- Negative results close rows too. Q4 answered with "the lenses are the same" deletes the
  lenses — that is the system working, and it has precedent
  ([ADR-0002](adr/0002-mechanics-in-scripts-judgment-in-prompts.md): two scripts, built,
  measured, deleted).
