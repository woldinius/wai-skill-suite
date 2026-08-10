# 0002 · Mechanics go in scripts; judgment stays in prompts

**Status:** accepted · 2026-07-13
**References:** [Anthropic — *Effective context engineering for AI agents*](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) · the **LLM-wiki** pattern (ingest → query → lint) · [`REFERENCES.md`](../../REFERENCES.md)

## Context

Two sentences, from two sources, describe the same failure — and the suite was committing it.

> **Anthropic:** *"Hardcoding complex, brittle logic in prompts to elicit exact agentic behavior
> creates fragility."*

The merge gate was six conditions a model had to remember on every run. And **"the model checked" is
not a thing anyone can audit.** You cannot grep it, you cannot diff it, and six months later you
cannot answer whether it happened. The failure case and the success case produce **identical output**.

> **The LLM-wiki pattern:** a knowledge base has three operations — **ingest, query, lint.**

This suite wrote documents and read them. It had **never linted them**. So: **55 of 89 dimensions had
no Red Flag** while every skill was being told to *"look up the Red Flag for ID X."* When a model is
told to look up something that is not there, it either invents a standard for that session or quietly
drops the finding — **and a clean review looks identical either way.** Two of the missing ones were
idempotent token consumption and "no plaintext PII in logs", both marked in our own testing strategy
as *mandatory* targets.

Not a bad prompt. **A missing operation.**

## Decision

**What is mechanically decidable moves out of the prompt and into a script with an exit code.**

- `merge-gate.sh` — `0 GO · 1 NO-GO · 2 UNKNOWN`. **Fail-closed: there is no path from "I could not
  check" to "go."**
- `catalog-lint.sh` — the third operation. Every dimension has a Red Flag; no duplicate IDs; no
  retired ID reused; every cited ID resolves.

**And what is not mechanically decidable stays with the model.** The gate is a **conjunction**: the
script owns the mechanics, the model owns the judgment. *No script can decide whether a finding is a
Blocker*, and one that tried would be worse than none.

## The line, and the two times a script crossed it

This is not a slogan. It has been tested, and the script lost both times.

1. **A cross-catalog collision check.** I wrote one that failed a repo for holding a live dimension
   whose ID the baseline had retired. It turned a repo **red that was right** — its `MAINT-6` is the
   lint gate; the baseline's retired `MAINT-6` was a modularity dimension. *Same number, two ID
   spaces, two unrelated concepts.* Whether two dimensions on one number **mean** the same thing is
   semantics. Deleted.
2. **A title-comparison heuristic** for the same problem. Built, run — **3 false positives in 10**, on
   the very data it was designed for. Deleted.

`wai-init` makes that call now, on reconcile, because it is a **model**.

> **A check that renders a verdict it cannot justify is how a lint gets switched off.**

## Consequences

- **The gate is auditable.** An exit code can be logged, diffed, and required in CI.
- **Determinism does not buy safety. It buys testability — and then you have to actually test.** The
  gate failed *open* under zsh (which does not expand a variable as a glob inside `case`), and later
  could never say **GO** in any repo (it read `SKIPPED` as a failure). Both shipped. Both looked fine.
  `tests/run.sh` exists because of that, and the two scripts now carry **29 cases** — every one a bug
  that shipped.
- **`shellcheck` is not a test.** It passed a `case … esac` inside `$( )`: valid POSIX, `dash` runs
  it, and it is a **syntax error in bash 3.2** — which is what `/bin/sh` *is* on macOS. CI therefore
  runs the tests on **two shells**.
- A script's findings must be **cheap to obey**. Three checks cried wolf in one week and one blocked a
  PR. *A check nobody can obey is a check everybody turns off* — and then it is worse than no check,
  because it is still right about what it catches and nobody is reading it.

  **And the fix for a wolf-crying check is always more PRECISION, never less STRICTNESS.** In one
  case the reviewer — me — proposed rewording the *documents* to dodge the regex. Overruled, and
  correctly: **that taxes every future document for a tool's imprecision, forever, and it will be
  forgotten. Fix the tool, not the writing it misreads.**
- **A green check must state what it cannot see.** `catalog-lint` passes an ID that exists in both
  catalogs meaning two different things — it *structurally cannot* see that, and now says so in its
  own output. **A green check that implies coverage it does not have is worse than a red one**, and
  the cost is concrete: one repo's `## Local IDs` section, written to satisfy the check, read as
  though it were the whole story. It was the lesser half.

## What this does not fix

**An artefact checks whether the work is right. It cannot check whether the QUESTION was right.**

That correction came from the field, and it is the sharpest thing said about this project. A finding
can be well-formed, rule-compliant and approved by every checker in the system — and still answer the
wrong question. One agent called a rule *"broken, because it never fires"* on an **invented
denominator**: measured, exactly **one** PR had touched product code. 0 of 1, and the zero was
correct. *"Every artefact in the system would have agreed with me. Every individual decision was
compliant. What I was missing was the reason."*

**And no artefact can check whether I kept a rule I decided to reinterpret.** A rule you talk
yourself out of is invisible to every checker there is.

Both were caught by the human. Neither by a tool. **That is the ceiling of everything in this ADR**,
and it should be read before the rest of it.


**It moves the failure, it does not remove it.** A rule in a prompt fails silently; a rule in a script
fails **loudly, in the wrong direction, until someone tests it.** The scripts took **nine repair
commits in two days.** They are the only deterministic thing in the suite — which means if they are
wrong, the thesis is wrong, and nothing else would tell you.

## Addendum 2026-08-06 — the principle has a name upstream

The external audit pointed at **Verifier's Law** (Jason Wei): *"the ease of training AI to solve a
task is proportional to how verifiable the task is"* — the asymmetry of verification. This ADR's
split is that law applied to the merge path: the script owns what is **cheap to verify** (an exit
code you can log, diff and require in CI), the model owns what is **expensive to verify**
(judgment), and where verifiability collapses — the question, the reinterpreted rule — **the human
is the design, not the fallback**. Nothing above changes; the reasoning simply turns out to have a
name and an upstream. Source and consequence: [REFERENCES.md](../../REFERENCES.md).
