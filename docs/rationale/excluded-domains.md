# `excluded-domains.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## One classifier, because two copies fail open

The suite had this logic in two places drifting apart: the merge gate's §5-6 path check (the
everyday "a human merges this") and a proposed autonomy guard (the "an agent must NOT touch this
unwatched"). Two copies of the most load-bearing safety question in the suite is two copies to
forget to widen. This is the single answer both callers ask, homed next to doctor.sh so nothing
keeps a private copy of the domain set. merge-gate.sh §5-6 delegate here; §4 (team-approval
enforcement) stays in merge-gate.sh — it is not this script's remit.

## Which repository do we ask about

WHICH repository do we ask about? `--repo OWNER/NAME`, else $GH_REPO, else gh's own default
(the local git remote).

THIS EXISTED NOWHERE AND IT WAS THE GATE'S ONE FAIL-OPEN PATH. `merge-gate.sh` gained a --repo
selector and threaded it through every check it makes itself — then delegated here with only
`--pr <n>`, and this script resolved the diff from the LOCAL remote. Against a checkout whose
`origin` points elsewhere (the field case that produced --repo in the first place), the gate
judged one repository while this classifier read a PR of the same NUMBER in another — and
reported CLEAR on a diff it had never seen.

Every other unresolvable state in this script returns 2 and holds. That one returned "clean".

## The citation dial: why unanchored citations stopped gating

Is a family ANCHORED — does this repo declare paths that belong to it? (#30, decided 2026-08-18.)
EX-GDPR anchors on a non-empty ERASURE_PATHS. EX-PAY/AUTH/API/SEC anchor on a CONTRACT_PATHS glob
whose SHAPE classifies into that family (the same contract_subtags read used for tagging); a glob
whose shape is indeterminate (EX-CONTRACT) anchors nothing — the paths themselves stay fully
protected by the path check regardless, this only scopes the advisory citation channel.

WHY: the widening rule ("a citation may only widen") was safe and it was measured expensive — in
a repo declaring no paths for a family, the false alarm stood ALONE three times, and the cheapest
route to a green gate became "don't cite catalog IDs": the exact opposite of what the suite asks
for. Where a family has no declared surface, a citation is documentation, not contact — it is
still REPORTED (an advisory line, visible in the verdict) but no longer DECIDES. Where the family
IS anchored, nothing changes. Paths and diff statements remain authoritative everywhere; under
--autonomy the advisory set still HOLDS the drain (autonomy errs closed, always).

## Three text channels, one reach

Besides the path list, the classifier reads text in three places: the erasure regex (EX-GDPR), the
catalog-ID citation scan, and the PR's own metadata. Until #67 the three had **inconsistent
reach**, eighty lines apart in the same script. The erasure regex read *added* lines, but from
*every* file — prose, ledger and run log included. The citation scan read the **whole diff file**
— context lines the author never touched, removed lines — plus the PR **title and body**. And the
variable holding title + body + labels was named for labels alone, so its detail line said
"widened by a gdpr/erasure label" when the trigger was the word *gdpr* in a paragraph, under a
single label named `ready-to-merge`.

WHY it changed is a measurement, not a taste. A field repo classified its last 64 merged PRs one
by one (field report of 2026-08-31 § 1c; its balance of 2026-09-06 over 259 verdicts):

- 10 PRs were tagged `EX-GDPR`. **9 came through the citation channel** — not one of them touched
  an erasure path; 1 came through `ERASURE_PATHS` (correct); 0 through the erasure regex.
- In **6 of the 10** it was the **only** exclusion reason — a GO otherwise.
- By trigger, across the PRs the report itemised: 5 from a **context line**, 2 from an added line
  of a **prose file**, 1 from **title and body alone** (no citation in the diff), 1 from an added
  **code** line (correct), 3 from `ERASURE_PATHS` (correct).
- Over the balance's 259 verdicts: 14 false positives, **12 of them this root cause**.

The shape matters more than the count. `wai-pr-review` cites the affected catalog ID in every
finding — the suite *requires* it — and the field repo's convention carries its run log and gate
ledger in most PRs as context. So the classifier tripped on the suite's **own mandatory citation**,
in the files the repo's **own convention** carries along, and the cheapest route to a green gate
was, once again, to cite less. That is the dial's incident (#30) a second time, one layer down: the
dial had scoped *which families* a citation may decide for; it had not asked *which lines* a
citation may be read from.

Three restrictions, all with the same thought — **a cited ID shows what the author means; it is not
a finding in itself** — and one rule about their reach:

1. **The citation scan decides from added code lines only.** Not a context line, not a removed
   line, not the title or body. `added_code_lines()` tracks the current file from the diff's
   `+++ b/<path>` header; a diff captured without headers is all code.
2. **Prose is a deny-list, and its incompleteness points at the gate.** `.md .markdown .mdx .txt
   .rst .adoc .org .rdoc .textile` are prose; an extension nobody listed — and a file with none — is
   **code**, so the channel keeps reading it and keeps widening. An allow-list of code extensions
   would fail the other way, on exactly the file type nobody thought of.
3. **Labels widen, descriptions do not.** A label is a declaration a human attached; a body is the
   text the suite told the author to fill with IDs. The variable is `LABELS`, and it holds labels;
   the title and body are no longer requested from `gh` at all — the test reads the stub's call log
   to prove it.

And the reach: **an added prose line is advisory, never deciding** — a citation or an erasure
statement in a `.md` is reported with its reason (`cited in prose, not code`; `in prose, not
code`), rides the verdict and the ledger row, and still holds the unattended `--autonomy` drain,
which errs closed as before. The field repo's own fix went one step further on one side and one
step less on the other — it dropped prose from the citation scan entirely and left the erasure
regex reading prose as gating; the suite chose one rule for both channels: visible, not gating.
Re-measured by the field repo against all 19 PRs it had ever tagged: **15 tags drop, 4 remain** —
the three erasure-module PRs and the one added code line — and no case in which the change hides a
real hit.

Unchanged, and pinned by the tests around this section: the path channel (`CONTRACT_PATHS`,
`ERASURE_PATHS`, `MIGRATION_PATHS`, the `EX-GUARD` floor), the destructive-migration grep (already
AND-gated on a migration path, so it needs no file-kind split), the dial's anchoring rule, and
`--autonomy`'s hold on the advisory set. `widen()` now names its tag in the anchored detail line
too — "widened by a cited PAY- family id" without an `EX-PAY` in front left the reader to infer
which tag had just been widened.

The field repo had carried this fix in its vendored copy of the script — a folder the next suite
update overwrites — with one red test as the only brake. That is why the change belongs here.
