# `verify-gap-breaks.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The red-probe replaced a prose promise

The skill used to assert "the gap must fail visibly" in prose and hope the model checked. "The
model checked" is not auditable. The script is: it runs the project's own test command and reads
the exit code, so the promise that a planted gap goes red is verified mechanically instead of
being trusted to the model's diligence.
