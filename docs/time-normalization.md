# Time normalization — every timestamp in this repo is date-only

**The rule: a timestamp this repo writes or publishes carries a DATE and never a wall-clock time.**
In machine-readable form that is `YYYY-MM-DDT00:00Z`; in prose it is the date, or a duration, and
no hour.

## Why

This repository is a curated re-publication of work done in private repos. The dates are real and
they are evidence — an undated field report proves nothing. **The hours are not evidence of
anything.** A row in the gate ledger carrying the hour does not make the verdict more auditable; it
records **when a human was at the keyboard**, in a public artefact, permanently, for every reader.
Across a few hundred rows that is a work-time profile nobody consented to publish: evenings,
nights, weekends, and the gaps between them.

The date carries the whole evidentiary value — ordering, sequence, "the same day", "seven days
open". The hour carries only the person. So the hour goes.

This is also a rule about *other* people: the suite runs in repos with more than one developer, and
the ledger and the report headers are written by a script, on their machines, into files they push.

## Scope — what must be date-only

- **Ledger rows** (`docs/architecture/gate-ledger.md` and every ledger the suite writes in a
  consuming repo).
- **Report headers** emitted by suite scripts (`dep-cve-scan`, `mine-issues`).
- **Prose in documents** — field reports, empirics, history, ADRs, audits, retrospectives. A
  sentence naming an hour gets rewritten. **Durations stay**: "sixteen minutes", "a few hours
  later", "the next day" carry the finding without carrying the clock.

## Where it is enforced

The three places in this repo that generate a timestamp are date-only **by construction**, not by
a reviewer remembering the rule (ADR-0002 — what is mechanically decidable does not live in prose):

| Emitter | Writes |
|---|---|
| [`merge-gate.sh`](../.claude/skills/wai-pr-review/scripts/merge-gate.sh) | the ledger row — `date -u +%Y-%m-%dT00:00Z` |
| [`dep-cve-scan.sh`](../.claude/skills/wai-security-audit/scripts/dep-cve-scan.sh) | the report header — same |
| [`mine-issues.sh`](../.claude/skills/wai-init/scripts/mine-issues.sh) | the report header — same |

Ordering **within** a day is not lost: the ledger is append-only, so the file order is the order.

## The exception: GitHub

**Timestamps that GitHub owns are out of scope, because normalizing them is not always possible.**
GitHub stamps commits, pushes, PR events, issue comments and Actions runs with the real time, on
its own servers, and the suite can neither suppress that nor rewrite it. Two consequences:

1. **Do not "fix" these.** `wai-team` records a run-start timestamp with a full
   `date -u +%FT%TZ` **on purpose**: it is never printed into an artefact — it exists only to be
   compared against GitHub's own `updatedAt`/`createdAt` fields, which carry real times. Rounding
   it to midnight would silently widen the window to the whole day and change what the cross-issue
   digest reports. A comparison bound is not a record.
2. **Do not claim more than is true.** Anyone with access to this repo's GitHub side can read the
   real times off the commits and the PR timeline. This rule keeps the *documents* clean; it does
   not, and cannot, make the work times unobservable.

## What is deliberately NOT normalized

**Test fixtures** (`tests/run.sh`, `tests/scripts.sh`, the learning-gap fixtures) keep their
invented hours — `09:00`, `12:05`, `13:10`. They are not records of anything: no human worked at
those times, and the values are chosen so that rows are *distinguishable and ordered*, which is
exactly what several checks exist to test (a run window, a ledger crossed with a git range, the
verbatim reason of one row among four). Flattening them to `00:00Z` would leave the tests passing
while testing less. **Invented data leaks nothing; the rule is about records.**

If a fixture is ever built by copying a real row, the copy carries a real hour — that has happened
once here — and then it is a record and gets normalized like any other.

## What this rule does not protect

Named so nobody reads more safety into it than it has:

- **Git commit timestamps.** Every commit carries author and committer time to the second. Making
  those midnight means rewriting history and force-pushing. Nothing in this repo does that
  automatically.
- **A clone's file timestamps.** They record when the *reader* checked out, not when anyone wrote.
- **GitHub's own metadata**, per the exception above.
- **Reconstruction from content.** Dates plus durations plus "the same night" still sketch a
  pattern. The rule removes the precise hour, not the shape of the work.
