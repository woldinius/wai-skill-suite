# 0001 · The catalog stays one file — the OKF split is rejected

**Status:** accepted · 2026-07-13
**References:** [Google Cloud — *How the Open Knowledge Format can improve data sharing*](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing) · [`REFERENCES.md`](../../REFERENCES.md)

## Context

`docs/architecture/quality-attributes.md` is the suite's standard: **91 dimensions in one file — 518
lines, ~36 500 characters, roughly 9 100 tokens.** It is the most-read artifact there is: **ten of
twelve skills consult it.**

The Open Knowledge Format proposes markdown + YAML frontmatter, one file per entity, addressable and
linkable. Applied here that reads as an obvious fit: one file per dimension, an `index.md`, load only
the dimension you need.

**I recommended the split. The user approved it. Then I did the arithmetic and reversed my own
recommendation.**

## Options

**A · Split into 91 addressable files.** Rejected.

The premise is that addressability buys selective loading. **It does not, because nothing here loads
selectively.** Every skill that consults the catalog needs the *whole* ID set and the Red Flag for
each — a reviewer cannot know which dimensions apply before reading what they are. So a split does
not reduce what gets read: it delivers **the same content through 91 file reads instead of one**, and
adds per-file overhead to every one of them. On the hottest paths the estimate at the time came out
sharply *worse*, not better.

*(The exact percentages from that estimate are **not preserved** — they lived in a conversation, and
this ADR exists because that is not good enough. The structural argument above stands without them,
and a deferred measurement would settle it. **Recording a number I cannot show would be the
same failure this file was written to stop.**)*

Two further facts, which is where the embarrassment lives:

- **OKF does not require the split.** `type` is its **only** required field, and a conformant consumer
  **must not** reject on missing fields, broken links, or a missing `index.md`. The 91-file structure
  was **my invention**, read into the format.
- The real token win the analysis surfaced needs **no split at all**: the router, `wai-cicd` and
  `wai-mobile-release` each load all **518 lines** when they need roughly **six IDs**. That is
  the finding worth having, and it survived.

**B · Adopt OKF's conformance properties without the split.** Deferred until the field data is in.
Frontmatter, stable IDs, addressability by anchor rather than by file. Cheap, and it keeps the door
open.

**C · Leave it alone.** Chosen, with B queued.

## Decision

**The catalog stays one file.** OKF conformance is pursued as a *format* question, never as a
*structure* one.

## Consequences

- **A dimension is not addressable as a file.** Accepted: it is addressable by ID, and the ID is what
  every skill, plan, issue and audit actually cites.
- **The ID string remains the suite's only linking primitive** — and it carries no provenance. That
  property later produced a live semantic-misbinding trap in two repos. See
  [ADR-0003](0003-the-baseline-owns-the-low-numbers.md). *A decision does not stop having consequences
  because it was correct.*
- The catalog is the suite's **token budget**, and it is now the only thing standing between the
  skills and the context window. `references/catalog-sizing.md` (the tier dial) is therefore load-
  bearing, and its central hypothesis — that `tier: compact` meaningfully cuts cost — **has never been
  measured.**

## What this does not fix

It does not make the catalog *cheap*. It establishes that **splitting it would have made it more
expensive**, which is a different and much narrower claim. The token question is open.
