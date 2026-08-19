# `run-log.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The record measured side effects, not work (issue #11)

Issue #11, measured in the field: before this file, a skill left a trace only if it FILED
something — a gate verdict, an issue. A security audit that finds nothing, a team run over eight
issues and three hours, a planning pass that comments on an existing issue: all ran, all
vanished. The record measured side effects, not work — and it was confident enough to be misread:
counting issues by skill showed 3 planning findings against 58 from pr-review, and a report
concluded from that that almost every PR was planned. The number was right; it measured issue
creation, not value produced. This file is the missing denominator.

## Rows per hand-back undercounted runs (issue #29)

"What counts as one run" is defined in the script's header because undefined it was measured
wrong (issue #29): rows were written per HAND-BACK, so a turn that implemented three subjects
logged one row and the count undercounted by a factor nobody could reconstruct.
