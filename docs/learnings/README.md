# Learnings — the evidence base

What actually happened, and what it cost. Kept because **the most expensive thing this project has
lost is not code — it is provenance.** Five sources were evaluated against this suite and recorded
nowhere; a token measurement that killed an architecture is gone; a merge race swallowed a security
fix. Every one of those was cheap to write down and impossible to reconstruct.

## Where a document goes

| | What it is | Lives in |
|---|---|---|
| **Evidence** | what happened, measured | `docs/learnings/` |
| **A foreign report** | evidence written **by another repo** | `docs/field-reports/` |
| **The running record** | the lesson distilled from each field run | `docs/empirics.md` |
| **A decision** | expensive to reverse; would look arbitrary later | `docs/adr/` |
| **A source** | something we were designed *against* | [`REFERENCES.md`](../../REFERENCES.md) |
| **A draft** | what we intend to *say*, outward | `docs/publication/` |
| **Genuinely temporary** | scratch, deleted when done | `temp/` (gitignored) |

## Naming

> **Evidence is dated. Drafts and plans are not.**

- **Evidence:** `YYYY-MM-DD-<source>-<subject>.md`
  A report is **only true as of the moment it ran.** We paid for that: a field report sixteen minutes
  out of date reported four non-problems with complete confidence, and the only way to tell was to
  re-run the tool. **The date is part of the content, not decoration.**
- **Drafts and plans:** `<subject>.md`, no date.
  They are *living*. There is no "as of". A draft gets its date when it ships — dating it earlier
  invites the reader to mistake it for a record.
- **`<source>`** names the repo the evidence came from — `backend-web`, `ios`, `android` — because
  **the field is not one thing.** Two repos produced statistics about the *same* failure class from
  different angles, and merging them would have lost exactly that. Generic, never a product name.

## Field reports: verbatim, foreign, and never edited

`docs/field-reports/` holds documents written **by another repo, in another repo's ID space.** Their
"MAINT-10" is *theirs*; ours does not exist. *(Plain quotes — because a backtick **is** a citation into
**our** catalog. I wrote that sentence with backticks and the lint failed the build, in the paragraph
explaining why it would. Fourth time this week. The convention is not decoration; it is the boundary,
and the tool holds it even against the person describing it.)*

Two rules follow, and both are load-bearing:

1. **`catalog-lint` does not lint them.** Per [ADR-0003](../adr/0003-the-baseline-owns-the-low-numbers.md),
   an ID never crosses that boundary. Linting a foreign document against *our* catalog is the same
   category error the skill scan used to make — and the answer is the same: **resolve each document
   against the catalog it was written for.** (`tests/run.sh` asserts this.)
2. **Never edit a field report to make a checker happy.** They are evidence. **If a report is wrong,
   that is itself the evidence** — one of them was, and the fact that a confident, well-written report
   can be entirely stale is one of the more valuable things in this directory. Annotate the correction
   in `docs/empirics.md`; leave the report alone.

## Append-only

**An entry is never rewritten to look better. A correction is a NEW entry that points at the old one.**

Adopted from the field, where it is enforced on an error ledger. The reason is the same one behind
`## Retired IDs`: **a record must mean one thing forever**, or every finding that ever cited it means
something else now. A document about preventing rot that is quietly edited to hide its own rot is
worse than no document.

The line, honestly drawn: fixing a **citation format** so a lint passes is not a rewrite. **Softening
a finding is.** This repo has done the first twice, in `empirics.md`, and it must never do the second.

**Field reports are exempt from the suite's English-only rule** *in the archive*. They are evidence,
in whatever language they arrived in, and the rule governs the *skills*. Translating a report is
editing it.

**And publication forced a decision on exactly that.** Eight of the reports below arrived in German.
A published report nobody in the audience can read is not evidence either — so the copies here are
**translations, each marked as one at the top**, and the verbatim originals stay in the private
archive, unedited. The rule above is not dropped; it is what makes the marking mandatory. A
translation is a derived document, and the reader is told which one they are holding.

## The lifecycle

```
temp/input/            an inbox. Read, triaged, DELETED. A document is "done" when it is
                       (a) built in and recorded, (b) an issue, or (c) rejected with the reason written down.
        ↓
docs/learnings/        what survives triage: the evidence, kept
docs/empirics.md       the lesson, distilled
docs/adr/  ·  issues   the decision, or the work
        ↓
docs/publication/      what we say about it, once it is true
```

## Two things that needed a decision — both decided at publication

**1 · Where evidence lives.** `docs/empirics.md` and `docs/retrospective-2026-07.md` sit at `docs/`
root while their sources sit in `field-reports/`. Publication settled it the other way round:
`field-reports/` moved up to `docs/field-reports/`, next to the record it feeds, and this index
links across. Still slightly incoherent, still cosmetic — but now at least it is one arrangement
instead of two.

**2 · Product names.** The reports named the products they came from. The rule *"no product names"*
now extends to `docs/`: every report published here refers to *"a production backend+web repo"*,
*"a production iOS repo"*, *"a game-server prototype"*. The originals keep the names and stay in the
private archive. The scrub is a **publication step**, not an edit of the evidence — the archived
document is still the one that counts.

## Index

| | |
|---|---|
| [`empirical-test-plan.md`](empirical-test-plan.md) | what still has to be measured before any of this is claimed in public |
| [`../field-reports/2026-07-14-backend-web-error-statistics.md`](../field-reports/2026-07-14-backend-web-error-statistics.md) | *"Of 47 defects found in a week, **0 were found by thinking.**"* |
| [`../field-reports/2026-07-14-ios-error-statistics.md`](../field-reports/2026-07-14-ios-error-statistics.md) | *the difference between minutes and weeks is not diligence — it is whether a mechanical check existed* |
| [`../field-reports/2026-07-15-backend-web-the-gate-said-go.md`](../field-reports/2026-07-15-backend-web-the-gate-said-go.md) | **the gate said GO — the first one, ever.** And the model declined to merge anyway |
| [`../field-reports/2026-08-02-prototype-review-verdict-not-on-pr.md`](../field-reports/2026-08-02-prototype-review-verdict-not-on-pr.md) | the full review existed only in a chat session — **the human noticed, not the skill** |
| [`../field-reports/2026-08-02-prototype-closes-needs-default-branch.md`](../field-reports/2026-08-02-prototype-closes-needs-default-branch.md) | merged, on `main`, tests green — and **every issue stayed open**: `Closes #N` fires only on the *default* branch |
| [`../field-reports/2026-08-02-suite-channel-loss-unread-feedback.md`](../field-reports/2026-08-02-suite-channel-loss-unread-feedback.md) | the channel carrying *"a result not in the system did not happen"* **lost that very lesson** |
| [`../field-reports/2026-08-02-prototype-field-session.md`](../field-reports/2026-08-02-prototype-field-session.md) | a tool error reported as a verdict · a gate that can never say GO · **a fuzzy measurement that invented a design decision** |
| [`../field-reports/2026-08-03-prototype-hook-blocks-test-fixture.md`](../field-reports/2026-08-03-prototype-hook-blocks-test-fixture.md) | the learning hook blocked a commit — on **its own test fixture**. Any repo that uses the mode *and* versions the suite hits it |
| [`../field-reports/2026-08-03-prototype-issue-mining-umlaut.md`](../field-reports/2026-08-03-prototype-issue-mining-umlaut.md) | mining split German words at the umlaut: the repo's strongest signal surfaced as two meaningless fragments |
| *(field-batch analysis & publication governance, 2026-08-03)* | what the 2026-08-02 batch is worth, what to build differently — and how to take external feedback once this is public. **Not published**: an internal planning document, in German; it remains in the private archive |
| [`../field-reports/2026-08-05-first-checkout-review.md`](../field-reports/2026-08-05-first-checkout-review.md) | the first cold checkout of the published repo: **three blockers on day one**, all of them a rule nothing checked — including an installer that destroyed the skills it was updating |
| [`../field-reports/2026-08-05-second-review-corrections.md`](../field-reports/2026-08-05-second-review-corrections.md) | the fix batch **misreported itself**: two findings marked Fixed that were not, and three new unbacked numbers — corrected here, append-only |
| [`../retrospective-2026-07.md`](../retrospective-2026-07.md) | the same week, counted from this repo: **reading the code found 3 of 22** |
| [`../empirics.md`](../empirics.md) | the running record — eight field runs |
