# Rationale — why the deciding scripts are written the way they are

Each file here holds the narrative that used to live in one script's long comment blocks: the
incidents, the field measurements, the traps that were tried and rejected. The scripts kept their
**rules**; this directory keeps the **reasons**.

## Why the split exists

A comment is free on disk and expensive in a context window. These scripts get opened — when a
skill says "run it", when a verdict is disputed, when anyone edits a check — and every time, the
whole comment head is billed. Measured on 2026-08-19, before the split: the shipped scripts carried
**29,180 words of comments against 27,440 words of code**, more prose than all thirteen `SKILL.md`
files put together, and 60 % of it sat in 68 blocks of eight lines or more.

Nothing was deleted. The record is the point of this repository, and a rationale that is only in a
commit message is a rationale nobody reads. It moved one directory over, where it stays citable and
stops being billed per run.

## What stays in the script, and what moves here

| Stays in the script | Moves here |
|---|---|
| `Usage:` and every `exit N` line — `contract-lint.sh` reads them | The incident that produced the rule |
| The rule itself, stated as a rule | The field measurement behind it |
| Warnings an editor needs *at the line they would break* | The alternatives that were tried and rejected |
| Fail-open / fail-closed declarations | Anything written in the past tense |

Each moved block leaves a pointer: `# Why: docs/rationale/<script>.md § <section>`.

## These files are dated evidence, not live claims

Read them the way you read a field report: **true as of the moment they were written.** They are
deliberately *not* in `numbers-lint`'s living-document set — a report's numbers age with it, and
re-measuring a 2026-07 incident against today's tree would turn a record into a lie in the other
direction. Where a number here describes a past state, it says so and carries its date.

Two consequences a contributor should know:

- **A catalog ID in backticks is a citation** and `catalog-lint.sh` checks it — including in this
  directory. An ID that belongs to another repo's ID space, or that never existed, goes in plain
  quotes: `"MAINT-10"`, not the backticked form. (Moving these files here made that rule bite
  immediately: three example IDs from script comments became citations the moment they landed
  under `docs/`.)
- **Do not "update" a narrative to match today.** If a rule changed, add the new state with its
  date; the old one is why the code looks the way it does.
