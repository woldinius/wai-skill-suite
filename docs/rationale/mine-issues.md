# `mine-issues.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The backlog is evidence a cold read of the code misses

wai-init writes a quality catalog. Left to a cold read of the code, it proposes the dimensions the
code SHAPE suggests — and misses the ones the team has been feeling for months but that leave no
structural trace: the label people keep reaching for, the word that recurs across a dozen bug
titles, the theme half the closed PRs share. That history is evidence, and evidence a catalog
author never sees is a catalog dimension never written. So this script surfaces it — as COUNTS the
model then judges, never as a verdict.

## An issue body is the most PII-dense text in a repo

Stack traces with usernames, customer emails, tokens pasted in a hurry — an issue body is the most
PII-dense text in a repo, and why the refusal to print one is the point, not a limitation. Mining
bodies wholesale into a catalog proposal would launder that PII into a committed doc. That is why
the script prints issue NUMBERS, never bodies; why bodies are read only behind `--bodies` and only
to widen the TERM_DF corpus; and why every email-shaped token is redacted before it is ever
tokenised.

## Why there is no exit 3

"You ran me in the wrong place" and "I could not reach GitHub" are different FACTS, but they are
the same DECISION for the caller: do not trust the mining, fall back to code-only. The distinction
belongs in the message, not the exit code — and the suite's precedent is settled:
excluded-domains.sh and merge-gate.sh both map misuse to 2. A private fourth code makes every
caller learn a per-script dialect.
