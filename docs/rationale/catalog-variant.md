# `catalog-variant.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## One master, derived variants

The suite offers the quality catalog in three sizes, and the obvious way to ship that — three
hand-maintained files — is the failure mode this repo documents everywhere else: a SEC fix that
lands in two copies out of three is a silent drift nobody notices, because a stale catalog reads
exactly like a current one. So there is one master (`quality-attributes.baseline.md`), and the
variants are derived from it mechanically; tests/run.sh regenerates and diffs the checked-in
variant files, so they cannot drift from the master without CI going red.
