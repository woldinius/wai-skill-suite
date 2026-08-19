# `catalog-lint.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## A citation is a backticked ID

A CITATION IS A BACKTICKED ID. That is the suite's convention everywhere — the catalog, the
skills, the plan and audit templates all write `SEC-3`. Requiring the backticks is not
pedantry; it is what keeps this check honest.

An earlier version used `.` as a wildcard where the backtick belongs, and matched substrings.
On its first field run it produced a 50% false-positive rate and BLOCKED a PR: it read "API-5"
out of an alert named `API-5xx-Rate`, and "AI-503" out of the prose "there is no AI-503 to
retry". Neither is a citation. The closing backtick is the boundary that makes them not match.
shellcheck disable=SC2086  # the file list must word-split

## No retired ID is reused

`## Retired IDs` exists because an ID string is the only linking primitive the suite has: every
review, plan, issue and audit cites them. Reusing one silently rewrites the meaning of every
finding that ever cited it.

THIS CHECK IS DELIBERATELY REPO-LOCAL, AND THAT IS NOT AN OVERSIGHT.
The obvious "improvement" is to also fail a live dimension whose ID the BASELINE retired. I wrote
it, ran it, and it failed a repo that was right: that repo has `MAINT-6 · Type-Check & Lint Gate
in CI` — live, closed, cited by its own issues — while the baseline retired its own MAINT-6 (a
modularity dimension) into `MAINT-1`. Same number, two ID SPACES, two unrelated concepts. Telling
that repo to renumber would have broken every citation in its issues and ADRs for nothing.

Deciding whether two dimensions on the same number MEAN the same thing is a semantic judgment, and
a shell script cannot make it. Same line as the merge gate: the script owns mechanics, the model
owns judgment — and a check that renders a verdict it cannot justify is how a lint gets switched
off. What IS mechanically decidable lives in check 4b: a *skill* must cite a LIVE baseline ID.

## Two classes of consumer, two catalogs

TWO CLASSES OF CONSUMER, AND THEY DO NOT RESOLVE AGAINST THE SAME CATALOG.

The repo's own DOCS — plans, audits, ADRs, the testing strategy — cite the repo's catalog. A
citation that does not resolve there is doc drift, and doc drift is what this check is for.

The SUITE SKILLS are vendored: installed by install.sh, owned by a manifest, authored elsewhere.
They were written against the BASELINE that ships beside them, and they cite ~80 of its IDs.
A repo tailors its catalog to its surfaces — to a SUBSET. So resolving skill citations against
the tailored catalog fails BY CONSTRUCTION in every consuming repo, on files that repo does not
own and cannot fix. The first field install of a second repo produced 26 such "findings"; not
one of them was actionable. A check nobody can obey is a check everybody turns off — and then it
is worse than no check, because it is still right about the things it does catch and nobody is
reading it any more.

So skills resolve against the baseline they shipped with. That keeps the bug this check was
written to catch — a skill citing `SEC-4` for IDOR when IDOR is `SEC-8` — while never failing a
repo for the entirely correct act of tailoring.
`field-reports/` is EXCLUDED, and that is ADR-0003, not an exemption.
Those files are verbatim documents from OTHER repos, written in ANOTHER repo's ID space. Their
"MAINT-10" is theirs; ours does not exist. The boundary rule says an ID never crosses that line —
so linting a foreign document against our catalog is the same category error the skill scan used to
make, and the answer is the same: resolve each document against the catalog it was written for.
They are evidence. Never edit one to satisfy a checker. If a field report is wrong, THAT IS THE
EVIDENCE (one of them was — a sixteen-minute-stale tool reported four non-problems). Annotate it in
`empirics.md`; do not touch the report.

## A doc may cite a retired ID

A DOC may cite a retired ID — an audit from March must stay readable, and that is what the
retired list is FOR. A SKILL may not. A skill is a live instruction executed today: the ID it
cites is the dimension a finding will be anchored to, so it has to point at one that still
exists. Citing a retired number anchors every future finding to a meaning that has moved.

Not hypothetical: this caught two of the suite's own artifacts citing `MAINT-6` for the
stub-gate incident — a number the suite's OWN baseline retired into `MAINT-1` (modularity).
The ID had been carried in from the repo where the incident happened, where MAINT-6 really is
the lint gate. In the suite's ID space it means nothing at all.

## A copied file must never cite a catalog ID

The vendored skills are safe: check 5 resolves their citations against the baseline, and install.sh
owns them, so they are never edited in place. TEMPLATES ARE NOT VENDORED — they are COPIED into the
repo, and the instant they are, every ID in them rebinds to the REPO's ID space.

The trap fired here. A ci.yml comment was re-pointed from `MAINT-6` to `MAINT-3`. Correct upstream.
Ported downstream it would have been WRONG — in that repo `MAINT-6` IS the lint gate and `MAINT-3`
is something else. And nothing would have caught it: `MAINT-3` is a valid, live, resolvable local
ID. It is a semantic MISbinding, not a dangling one, so no reference checker sees it, and it looks
exactly like applying an upstream fix — which is what one is supposed to do.

So a copied file NAMES the dimension and never numbers it. Names do not collide.

## Locally-minted IDs sit outside the baseline number space

An ID carries no provenance. `MAINT-3` looks identical whether it is the baseline's or this repo's
own — and that is the root of every collision the suite has hit. The split: the baseline owns the
low numbers, a repo that mints its OWN dimension starts at 100. Two digits shared, three digits
local, readable at a glance and checkable here.

Pre-existing sub-100 locals are PERMANENT (an ID is never reassigned), so they are DECLARED under
`## Local IDs` rather than renumbered. That declaration is the translation table — the thing that
has to exist forever anyway. Failing on them forever instead would just get this check switched off.

## What these two lines cannot see

WHAT THESE TWO LINES CANNOT SEE — and the comment must not pretend otherwise.
An ID present in the baseline is ASSUMED adopted. It is never verified to MEAN the same thing.
A number that means one thing here and another upstream is a MISBINDING: the reference resolves,
nothing dangles, and no lint can see it. One field repo holds FIVE of them right now — its
`SEC-8` is CSRF hardening where the baseline's is IDOR — and every one of them passes here.
This check catches the FUTURE hazard (a new local mint a later baseline dimension could take).
It is blind to the LIVE one, which is the dangerous half. Saying so is the whole point: a green
check that implies coverage it structurally cannot have is worse than a red one.
