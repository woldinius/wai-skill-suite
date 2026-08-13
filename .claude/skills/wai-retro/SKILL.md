---
name: wai-retro
description: >-
  Periodic retrospective of the suite's own work, built from artifacts at a threshold — never from
  recall. Reads the gate ledger's report extract, the run log and git history; writes a dated,
  narrated report where every rate carries its raw row counts, and finishes by advancing the
  ledger's report marker so the cadence resets. The collaboration level is gated until a question
  trace exists, and publication to the suite repo happens only on explicit request, sanitized and
  pseudonymized. Use it when doctor reports the verdict threshold since the last report marker, or
  on request: "run the retro", "retrospective", "what did the suite do this month", "cut a report",
  "how many runs". Not the per-PR review (wai-pr-review), not the structural or security audits
  (wai-architecture-audit / wai-security-audit), and not a metric dashboard — artifacts in,
  narrative out, the judgment column stays human.
license: MIT
---

# Retro (periodic, artifact-derived)

Turn a period's accumulated evidence into a retrospective — **from artifacts, at a threshold,
never from recall**. The gap this skill closes was measured twice (issue #14): *reports happen
when someone asks* — roughly 250 verdicts of field friction produced zero reports in between,
and a three-week ledger waited for a human to wonder before anyone measured it. And recall is
not a fallback: retrospected from memory, one long field session reported **2 of 6** verified
collaboration failures — and described one of the missed ones as handled. Any self-check an
agent performs on its own conduct reports the comfortable answer unless it is anchored to an
artifact.

## Trigger

Two ways in, and the hand-back says which one fired:

- **Threshold.** `sh ../wai/scripts/doctor.sh` (from this skill's directory) prints the
  report-cadence advisory — "N verdict(s) since the last report marker", threshold 25 (override
  `REPORT_THRESHOLD` env). At or over the threshold, a retro is due; doctor stays advisory
  (`exit 0` with the note; `exit 1` is repo **DRIFT**, `exit 2` is doctor's own **UNKNOWN** —
  neither is the retro trigger, both are findings to carry into the report).
- **Explicit invocation.** The human asks — "run the retro", "what did the suite do this month".
  A retro on request is legitimate below the threshold; the report states the trigger either way.

## The three-layer split (ADR-0002)

**Scripts extract the numbers → the model writes the narrative → the human owns the judgment.**
Concretely:

- This skill **never computes in prose a rate that a script emits**. The false-positive rate, the
  calibration share, the traced share — those numbers are pasted from script output, verbatim.
  A retro that re-derives them by hand is a second parser, and second parsers drift.
- **Every rate appears with its raw row counts beside it** — the counter-reader principle: the
  measuring chain itself errs, and a 0% that was really 15% once shipped inside the very line
  meant to prove trustworthiness. Raw counts are what let a human read against the rate.
- The **outcome column belongs to the human**, and its vocabulary includes the fifth outcome a
  field run surfaced: *"verified: the condition was already met; hardened so it stays that way"*
  — without it, that result gets misfiled as either "done" or "parked".

## Inputs — and the one document this skill does not read

The retro's inputs are the **gate ledger** (via its one authorized parser), the **run log**,
**git history**, and the **open-items footer**. Deliberately **not** an input: the quality
catalog. Its dimension IDs anchor findings about *code*; a retro's rates are measurements of the
*suite*, not dimension findings, so citing the catalog here would dress statistics as review
results. There is also a counted reason: the number of catalog-reading skills is a lint-checked
claim in this repo's prose, and a reader that consumes nothing from the file would move that
count without adding information. This skill stays a non-reader.

## Process

1. **Confirm the trigger and the period.** Run `sh ../wai/scripts/doctor.sh` (from this skill's
   directory) if the trigger was not already its advisory. The period is everything since the
   ledger's last report marker (the default anchor `scripts/retro-compliance.sh` derives), or the
   range the human names.

2. **Collect — scripts only, fail closed.**
   - `sh ../wai-pr-review/scripts/gate-stats.sh --report` (from this skill's directory; **without**
     `--mark` — the marker is planted at the end, step 6). `exit 0` = the dated report section was
     emitted · `exit 2` = no ledger to read — then level 1 has no gate half: say `not measured`,
     never reconstruct verdicts from memory or from PR pages.
   - `sh scripts/retro-compliance.sh` (from this skill's directory) — the compliance metric: it
     crosses run-log rows, gate-ledger rows and `git log --merges` and reports per-skill run
     counts, the period's verdict count, the merged-PR count and the **traced share** (which
     merged PRs carry a gate verdict), raw numbers beside the rate. `exit 0` = emitted, including
     named-empty lines for an empty period · `exit 2` = an input could not be read — the affected
     lines are `not measured`, and a share over a missing source is not a smaller measurement.
     It takes `--since YYYY-MM-DD` when the human names a period. It is an extractor, not a run:
     it writes no run-log row itself.
   - **The closing picture** comes from `sh ../wai/scripts/open-items.sh` (from this skill's
     directory) at hand-back — `exit 0` = footer emitted (empty lines name their derivation) ·
     `exit 2` = nothing derivable, then say `not checked` yourself.

3. **Level 1 — suite performance (narrate the pasted numbers).** What the gate, the skills and
   the checks did over the period: verdict totals and the fp/fn rates from the gate report;
   the calibration signal (correct-but-unwanted NO-GOs) as the usefulness dial; run counts per
   skill from the run log; the traced share as the suite monitoring its own prompt-contract
   weakness — a merged PR without a verdict row is a review that ran without its script, or
   never ran, and the narrative names which artifacts could tell. **Absence of failure is a
   first-class result:** a codebase that stayed continuously runnable for three weeks was
   captured by no metric — when it is true, say it, **with its denominator** (over how many
   merged PRs, over which window). A report where everything went well and nothing is measured
   is worthless; a measured quiet period is the strongest single result a period can produce.

4. **Level 2 — collaboration: GATED, and this skill says so.** The collaboration retro needs a
   question trace — an artifact for "asked, unanswered" — and that artifact does not exist yet.
   Until it does, the retro prints the honest line the open-items footer already prints:
   `not derived — no artifact exists`. **Never reconstruct collaboration failures from memory**
   — that is the measured 2-of-6 failure this skill exists to not repeat. The checklist of
   failure modes (decisions that vanish, questions silently dropped, process skipped on one's
   own code, opt-in modes suspended unsurfaced, guardrails moved without asking) stays in the
   report as *what will be measured once the trace exists*, not as recalled findings.

5. **Write the dated report** to `docs/architecture/retrospectives/<YYYY-MM-DD>.md` (create the
   folder if needed) using the format below. The human completes the outcome column; Blocker-class
   findings about the suite (a gate that lied, a metric that dropped rows) are the human's
   decision point — present with a recommendation and wait.

6. **Advance the marker:** `sh ../wai-pr-review/scripts/gate-stats.sh --report --mark` (from this
   skill's directory). The `--mark` **appends** one marker line to the ledger — an append, never
   an edit — and it is what doctor counts from: **an unmarked retro does not reset the cadence**,
   so skipping this step re-arms the advisory against a report that already exists. `exit 2` here
   means the marker did not land (the report above stands) — say so in the hand-back.
   (`--mark` without `--report` is refused by the script: a marker must record a report that was
   actually cut.)

7. **Level 3 — publication, on explicit request only.** Nothing leaves the repo by default. When
   the human asks for it, produce a **sanitized English extract** for the suite repo as a dated
   field report (`docs/field-reports/YYYY-MM-DD-<slug>.md` there, following its `TEMPLATE.md`):
   - **Pseudonym, not name:** the report carries the field-repo identifier `fr-<12hex>` — the
     first 12 hex digits of a keyed hash (HMAC-SHA-256) of the repository URL. The key is random,
     minted once per reporting repo, stored **gitignored in the private repo** (intended home for
     minting: `wai-init`), and never leaves the reporter — so evidence groups across reports
     without naming its source, and no outside party can confirm a guessed URL against it.
   - **Suite version** (from `.claude/.wai-suite-version`, or `not stamped`) rides along, so
     findings attach to the tree that produced them.
   - **Sanitization is checked before anything leaves:** English only; no product or repo names;
     no cross-repo issue numbers; numbers instead of names, classes instead of domain specifics;
     no timestamps beyond dates unless the source repo wants dates dropped too.

8. **Log the run and hand back.** `sh ../wai/scripts/run-log.sh wai-retro "<period>"
   "<half-sentence result>"` (from this skill's directory) — fail-open: `exit 0` even when the
   write fails, `exit 2` only on misuse (missing arguments). Then the open-items footer (step 2)
   verbatim beneath ▶ Recommended next, then the recommendation — the script derives, the model
   recommends, in that order.

## Report format

Use exactly this structure for `docs/architecture/retrospectives/<YYYY-MM-DD>.md`:

```
## Suite retrospective: [repo] · [YYYY-MM-DD]

**Period:** [anchor → today · what set the anchor: last report marker / --since / all rows]
**Suite version:** [stamp, or `not stamped`]
**Trigger:** [threshold — N verdicts since the last marker, threshold T | explicit request]

### The numbers (script-derived, pasted verbatim)
[gate-stats --report output]
[retro-compliance output]

### What held
- [each claim names the artifact it stands on; absence of failure stated WITH its denominator
   when true — and only when an artifact backs it]

### What broke
- [wrong verdicts, dropped rows, checks that cried wolf — artifact-anchored, raw counts beside
   every rate]

### Calibration
- [the correct-but-unwanted NO-GO share and fp clusters from the gate report — the gate's
   usefulness dial, distinct from its correctness]

### Compliance — did the work leave a trace
- [the traced share and per-skill run counts; a low share is a finding about the SUITE's prompt
   contracts, not about the people]

### Collaboration
not derived — no artifact exists (a question trace is the prerequisite; nothing here is recalled)

### Outcomes (the human's column)
| finding | outcome |
[vocabulary: done · parked · rejected (with reason) · verified: the condition was already met;
 hardened so it stays that way]

### ▶ Recommended next
1. [ranked actions, each naming the skill that takes it]
```

Omit empty sections — except **Collaboration**, whose honest not-derived line *is* its content
until the trace exists.

## Principles

- **Artifact-first, recall never.** Every claim names the artifact it stands on; an empty list
  names its derivation or prints `not checked`.
- **The ADR-0002 split.** Scripts extract, the model narrates, the human judges. A generator
  that decided per run what is "reportable" would be judgment smuggled into a script.
- **No success stories — but absence of failure is a measurement.** Both belong in the same
  report, and the quiet result carries its denominator.
- **Every metric needs a counter-reader.** Raw row counts beside every rate, always — the
  measuring chain itself errs.
- **Threshold, not mood.** The suite announces when a report is due (doctor's advisory) instead
  of waiting to be asked; the retro that answers it advances the marker so the count restarts.
- **Nothing leaves the repo by default.** Publication is explicit-request only, sanitized,
  pseudonymized, versioned.

## Git & PR

**The authority is `references/agent-git-protocol.md` (in the `wai` skill).** Specific to *this*
skill: commit the dated report on an `agent/<handle>/chore-retro-<YYYY-MM-DD>` branch and open a
PR — like the audits, **never commit, push or merge to `main`**. The ledger and the run log are
append-only: the retro reads them and appends exactly one marker line (via step 6); it never
edits a row. A sanitized extract for the suite repo is a change *in that repo* and follows that
repo's flow — it is never pushed anywhere as a side effect of the retro run.

## Related Skills

This skill is the **periodic retrospective stage** — the per-period sibling of the per-hand-back
open-items footer:

- **wai-pr-review** — owns the gate and the ledger the retro reads; `gate-stats.sh` is its
  script and stays the one ledger parser. Per-PR judgment lives there; per-period narrative here.
- **wai-architecture-audit** / **wai-security-audit** — the other periodic skills; they audit
  the *codebase* (structure, attack surface), this skill audits the *suite's own record*. Their
  dated reports are inputs to the period's story, not outputs of it.
- **wai** — ships doctor (the trigger), the run log writer and the open-items footer this skill
  consumes.
- **wai-init** — intended home of field-id key minting; until it lands there, step 7 documents
  the manual mint.
- **wai-implementation** — takes the ▶ Recommended next actions that are code changes.
