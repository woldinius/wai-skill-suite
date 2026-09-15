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

## MOOT is blank by rule, so it is not untagged

The ledger header `merge-gate.sh` writes into every new ledger says of a `MOOT` row: *leave its
outcome blank and do not count it in fp/fn* — a review that ran after the merge decided nothing,
and the row's value is that it records the gate ran too late rather than never. This counter
contradicted its own header: every blank MOOT row went into `untagged`, and `untagged` is the
number the weekly review is asked to drive to zero. In this repo that put 6 rows under *untagged*
of which 2 were MOOT blanks; the field balance of 2026-09-06 kept its 10 MOOT rows out of the
confusion matrix for exactly the header's reason; and `open-items.sh` had already learned to exclude
them — two readers of one file disagreeing about the same rows (#69).

Now a blank MOOT is counted as what it is (`MOOT n blank by rule`, beside `untagged`, never inside
it), coverage is reported over the *judgeable* rows (total minus MOOT), and a **tagged** MOOT row is a
data-quality line: the tag has no rate to enter, so it can only mean the rule was not followed — the
same class as the `fn`-on-NO-GO line, which the field balance called an instrument finding, not a
gate finding. `numbers-lint` re-measures Q1's *untagged* from this output, so the open question's
number followed the definition the day this landed.

## A reconstructed row has no outcome

Field ledgers lose rows — to a squash race, to a vendored-copy update — and the repo that lost
them rebuilds the row from the verdict the PR comment still shows, tagged `LOST`. The field
balance of 2026-09-06 ([report](../field-reports/2026-09-06-two-months-of-gate-259-verdicts.md))
carried four such rows and kept them out of its confusion matrix. This counter reported them as
*unmatched* — a data-quality alarm for a row whose state is known and deliberate.

A reconstructed row has a verdict (the script did emit it once) but no judged outcome: the tag
says *where the row came from*, not whether the gate was right. So `lost` — matched on its first
two characters, case-insensitive, like every tag — is counted on its own line and enters **no**
rate: not fp/fn, not calibration, and not outcome coverage either (it leaves both the tagged count
and the judgeable denominator, the way MOOT does). Its verdict still counts in the verdict totals
and the NO-GO cause split, because the verdict is known. A tag that is neither known nor `lost` —
`manual`, say — is still counted as unmatched and named.
