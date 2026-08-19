# `backlog-scan.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## Why a script and not the model reading the backlog

The reason the proposal is emitted by a script and not by "the model reads the backlog": the
frontier and the default order are a dependency computation, and a model re-deriving a topo order
by eye on every run is exactly the brittle-prompt failure ADR-0002 exists to remove. Compute it
once, in the script, and let step 2 refine a single source instead of inventing its own.

## A mechanical fact must not wear a verdict's clothes

A checklist-free issue can be perfectly workable and a checklist-heavy one can be noise — which is
why the scan refuses to grade "actionable". Emitting an "actionable: no" verdict from a checkbox
count is the same category error as a lint that fails a repo for tailoring: a mechanical signal
wearing a semantic verdict's clothes. So the script emits the fact and names it a fact; the
drop/keep judgment stays with the model.

## Attendance: a run that files nothing vanishes

Issue #11 found that the record measures side effects, not work — a team run that files nothing
vanishes from the record. That is why the scan self-logs its own run-log row: it opens every
wai-team run and maps 1:1 to that skill, so attendance is written by the script at scan time, not
remembered at report time.
