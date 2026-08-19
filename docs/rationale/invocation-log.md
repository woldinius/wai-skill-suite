# `invocation-log.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The prompt-written tier was measured and had gaps (#29)

This script was decided in issue #29 on 2026-08-18. The run log's two tiers were measured in the
field: the script-written tier logged 9 of 9; every prompt-written tier had gaps —
architecture-audit 0 rows with a committed report, learning-gap 0 rows with a ledger entry,
implementation 4 of 5. Self-logging that depends on the model is not a measurement. The fix is
the two artifacts the script's header names — this mechanical denominator with no outcome column,
and run-log.md as the model-written numerator — never merged.

## A crafted skill name forged denominator rows

The skill name is the one field a row takes from the hook payload, and a name carrying '|' forged
extra columns — a crafted skill name minted rows with a fake timestamp and skill, corrupting the
very denominator this log exists to make trustworthy. Hence the table-safe sanitisation
(run-log.sh's cell() shape) before the append.
