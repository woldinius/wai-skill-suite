# DEFECT: `mine-issues.sh` fragments German words at umlauts — TERM_DF returns fragments

> Translated from the German original; the original remains in the private archive. The product
> repo is anonymized (a game-server prototype; German-language repo, `Docs language: German`).

**Found:** 2026-08-03, `wai-init` step 5a, on the 2026-08-02 suite version.

## Observation
`scripts/mine-issues.sh` over 63 issues yielded, among others:

```
TERM_DF term="ude"  df=11 examples=#61,#58,#30     ← from "Gebäude"  (building)
TERM_DF term="geb"  df=8  examples=#61,#58,#23     ← from "Gebäude"
TERM_DF term="ger"  df=4  examples=#29,#18,#15     ← from "Träger"   (carrier)
TERM_DF term="tzlich" df=2 examples=#48,#29        ← from "zusätzlich" (additional)
TERM_DF term="zus"  df=2  examples=#48,#29         ← from "zusätzlich"
TERM_DF term="che"  df=2  (CLOSED_PR_THEMES)       ← from "Küche"    (kitchen)
```

The run's most frequent "terms" were therefore **word fragments**. `Gebäude` (11 issues — by far
the repo's strongest content signal) appeared as two separate fragments `geb` (df=8) and `ude`
(df=11), each meaningless on its own, with counters that contradict each other on top. A catalog
author reading this list does not see the actual theme.

## Cause (assumption — please verify)
The tokenisation apparently splits on `[a-z]` classes or treats non-ASCII as a separator. Umlauts
(ä ö ü) and ß thereby split mid-word. Affected are all non-English languages with diacritics —
exactly the repos for which the skill explicitly provides `Docs language: <other>`.

## Impact
Not critical (the script explicitly states "COUNTS are evidence, not a verdict"), but it
**devalues step 5a for non-English repos**: the top signals are noise, the real signal is
fragmented and invisible. Since the skill presents the mined candidates to the human as
proposals, this costs either time or a missed catalog dimension.

## Proposal
- Switch tokenisation to Unicode letters instead of `[a-z]`/ASCII — in POSIX `tr`/`awk` that is
  ugly, but a `grep -o` with a character class including the common diacritics, or a `sed` that
  splits only on whitespace/punctuation, would go far.
- At minimum: extend the stopword list with German filler words. In the same run `mit`, `als`,
  `ist`, `ein`, `auf`, `und`, `neue`, `neues` ranked high — that too is noise, independent of the
  umlaut problem.
- Alternatively document it honestly: "TERM_DF is designed for English text" — then the catalog
  author knows to ignore the signal for repos in other languages.

## What worked well regardless
`LABEL_FREQ` and `CLOSED_PR_THEMES` (where prefixes were English, like `feat`, `overlay`) were
usable and language-independent. The principle "numbers, no bodies; example NUMBERS instead of
text" is exactly right and emitted nothing sensitive during the run.
