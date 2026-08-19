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
