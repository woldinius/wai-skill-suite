# `gate-stats.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The 0% that was 15%

The first parser compared outcome tags LITERALLY: `outcome["NO-GO/ok"]`. Then a three-week field
ledger arrived (issue #10) in which the human's vocabulary was finer than two letters — `fp, bug`,
`ok, besser GO`, `ok, manual fix` — and none of it was `ok` or `fp` to a string comparison. Twenty
of fifty-two judged NO-GO rows fell out of the statistic, unannounced, and the output read
"false-positive rate: 0%". The true value was 15%. The zero was not a measurement; it was a parser
artifact, sitting in the very line meant to prove the gate trustworthy. That is what bought the
rule the script keeps: the tag is the first two characters, the free text after a comma is the
human's and is preserved — and any tag the parser cannot place is counted and printed, because a
statistic that drops rows must say so.

## The cwd default that reported a false blank

The default ledger path used to resolve from the cwd. That made a documented invocation report
"no ledger" over a repo that had 28 rows — a false blank. The default is repo-relative now,
matching merge-gate.sh, the writer this script reads.

## Why setup outranks checks outranks domain

The precedence setup > checks > domain in the mechanical cause classification matches how the
field report counted: a row failing on environment AND domain is an environment problem first —
the remedy the gate prints 55 times is "declare required checks".

## Eleven besser-GO rows sat unread for three weeks

`ok, besser GO` marks a block that was correct by the rules while the human says GO would have
been fine — the most precise feedback a gate can get. Eleven of these sat unread in the field
ledger while the gate went unchanged for three weeks; the calibration line in the report exists
so that signal is surfaced instead of buried in free text.
