# `ledger-lint.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The same hole catalog-lint closed, one level down

A ledger has ingest (the skill WRITES rows) and query (it READS boxes to choose a gap). It never
had a lint — the same hole catalog-lint.sh was written to close, one level down. So an axis label
could be a typo the box-weighting silently ignores, an enabled axis could carry no level, two gaps
could be open at once, and a Socratic gap could record NO expected answer — fatal, because with
nothing recorded the gap can never be marked solved and rides along invisibly. Nothing checked.
This script is the check that closed that hole.
