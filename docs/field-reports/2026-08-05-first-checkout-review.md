# The first cold checkout found three blockers on day one

**Source:** the first checkout of `wai-skill-suite` by a reader who had not built it —
an agent-assisted review commissioned by the owner, one day after publication.
**Date:** 2026-08-05 · **Subject:** the published repo at `v0.1.0`

This is a field report about **the publication itself**, not about a project the suite was
applied to. It belongs here for the same reason the others do: it is what happened, measured, and
the outcome column is not the suite's to grade.

---

## The shape, and it is the repo's own thesis pointed inward

Every blocker below is the same failure this suite exists to argue against: **a rule that nothing
checked.** Not one of them is subtle. All three would have been caught by a check that did not
exist, in a repo whose entire claim is that mechanics belong in checks.

The verdict of the review — *"conceptually and structurally well above average; the publication
layer lags the substance"* — is accurate, and the last clause is the useful half.

---

## Blockers

### B1 · The documented update path destroyed the skills it was updating

Under `curl … | sh`, `$0` is the shell, so `dirname "$0"` is `.` and the script took the **target
project** for its own checkout. A target that already runs the suite has a `.claude/skills`, so
the check that asks "am I inside a checkout?" said yes — about the destination. The install loop
then ran `rm -rf` on each skill and `cp` from the directory it had just deleted.

**First installs were always fine. Only updates hit it** — and the path is recommended twice in
the README. The three repos running this suite are exactly the ones that would have taken it.

**Outcome: fixed.** Checkout mode now requires the script to run as a file, plus an independent
rip cord that refuses when source and destination are the same directory. Both are tested, and
the test was verified red against the old script.

**The more useful part is the first test attempt.** It set `SKILLS_REPO` to a local path to stay
offline — which disables the very branch under test, because checkout detection is guarded by
`[ -z "$SKILLS_REPO" ]`. It passed against the broken installer. A `git` stub now intercepts only
the clone, and the case fails red with the evidence in plain text: `source: this checkout
(…/install-piped)`. **A test never seen red is not a test.** The suite says that about gates; it
turns out to be just as true about the tests of gates.

### B2 · The only skill with valid YAML was the only one losing its description

`wai-requirements-planning` was cut at the `#` in `("plan #42")` — 61 % of its description gone,
including every trigger phrase and the whole demarcation against the other skills. At runtime the
lifecycle effectively began at step 2, because `wai-implementation` with its broad triggers wins
whatever planning stops claiming.

The cause is worth the space: it was **the only frontmatter that parsed as YAML.** The other
eleven carry an unquoted `: ` in the description, which makes them invalid — so the loader falls
back to raw text and they survive complete. Proof in the skill listing: `wai-team` shows
`"process issues #12–#18"` intact, `#` and all. **Eleven skills were right by way of being broken,
and the twelfth paid for being correct.**

**Outcome: fixed.** All twelve descriptions are folded block scalars (`description: >-`), where
`#` and `:` are literal — valid *and* complete, verified round-trip against the original strings.

**And it exposed two checks that had quietly stopped checking.** The description-length assertion
began measuring the two characters `>-` and went green on everything; the angle-bracket assertion
began failing on the `>` that is syntax rather than content. Both were in the file whose header
argues that a green check implying coverage it does not have is worse than a red one.

### B3 · The Evidence section was made entirely of dead links

Twenty-nine relative links did not resolve. Eighteen were in the README's **Evidence** section —
the one carrying the claim that every assertion here is checkable — pointing at `docs-pub/`, a
directory name that only ever existed in the repo this one was built *from*. A reader following
the honesty claim landed on nothing, eighteen times.

Two migration artefacts (`.all-files`, `.done-files`) were committed at the repo root and explain
the cause: 26 of their entries name `docs-pub/` paths. **The migration script's own completeness
check excluded them by name**, which is precisely why it did not notice.

**Outcome: fixed**, plus a test: every relative markdown link in every tracked `.md` must resolve.
Its first version crashed instead of failing, because an unbraced `$f->$t` swallowed the separator
into the variable name — a test that crashes is not a test that fails usefully, either.

---

## Majors

| # | Finding | Outcome |
|---|---|---|
| M1 | Catalog size quoted as "89 IDs, ~440 lines" in four places; it is 91 and ~530. Pointed, because those numbers are in the text *because* they are mechanically checkable. The suite's own audit filed this on 2026-08-03 and proposed a numbers lint — the finding then aged in place. | **Fixed.** Also: "eight skills read the catalog" → nine, counted; "24 scripts" → 23 (a deployment *template* had been counted as a suite script) |
| M1b | The README claimed tests/ holds "199 cases, **each one** a bug that shipped". The retrospective in this same repo records that exact sentence as false, in the owner's words — *"It is 8 of 29"* — and it shipped anyway, two directories from its own refutation. | **Fixed**, and the correction is named in the text rather than quietly swapped |
| M2 | Two contradictions the suite's own audit filed against itself on 2026-08-03, still open: "Always plan first … not even for trivial tasks" vs. "a small change needs no plan at all"; and audit cleanups applied "never committing" vs. three statements saying to commit them on a branch and open a PR. | **Fixed.** Plan is proportional, never optional; approved cleanups go on a branch and into a PR |
| M2b | The review read `history.md`'s "the two blockers are closed" as wrong ("it was four"). | **No change — the claim is correct.** The audit's Blocker section lists two, and both verify as closed: `merge-gate.sh` passes `--repo` into the classifier, `open-gap-check.sh` exits 0 here. The two counted as third and fourth are the M2 contradictions, now closed as well |
| M3 | The README sells local hooks as an enforcement layer. Nothing sets `core.hooksPath`, so git looks in `.git/hooks` and **never runs them** — including in this repo. `pre-push` was never linted; the wai-learning-gap harness (88 cases) ran in no CI at all. | **Fixed.** `doctor.sh` reports unwired hooks as DRIFT and carries the one-line fix; CI lints `pre-push` and runs the learning-gap suite |
| M4 | The social draft claimed a restructuring would have been "94 % more expensive" — a figure this repo documents as preserved **nowhere**, twice, sitting in the directory whose rule is that untraceable claims do not ship. | **Fixed.** The draft now makes the claim ADR-0001 supports (direction only) and says why the number is absent |
| M5 | `.all-files` / `.done-files` tracked at the repo root. | **Fixed** (see B3) |

The rest is **filed**, per the landing rule — a finding is fixed, filed, or rejected with a
reason, never noticed and dropped:

| Issue | Finding |
|---|---|
| #1 | exit 2 carries two meanings (MOOT vs UNKNOWN) |
| #2 | "merge gate" names three different artefacts; three skills claim ownership |
| #3 | unqualified cross-skill references to `wai/references/*` do not resolve |
| #4 | `mine-issues.sh` fragments non-ASCII words at diacritics |
| #5 | `attack-path-lint.sh` rejects its own skill's documented template |
| #6 | two `handoff-lint.sh` defects, incl. `check-ignore` without `--no-index` |
| #7 | a numbers lint for mechanically checkable claims — proposed by the 2026-08-03 audit, still not built |
| #8 | the "Platform context" block duplicated across seven skills; `wai-learning-gap` at 4998/5000 words |
| #9 | this repo runs no gate ledger of its own, so its own gate claims are anecdotal |
| #10 | no release/versioning or incident/rollback role; a referenced "comms skill" does not exist |
| #11 | publication itself has no checks — the general form of all three blockers |

---

## What this cost, and what it bought

Seven fix commits, six new test cases, three new checks that did not exist:
a link resolver, a strict-YAML frontmatter guard, a hooks-wiring probe.

**The honest reading:** publication was treated as a migration, and migrations were the one thing
this suite had no check for. Every skill, script and protocol went through review, tests and a
gate. The *packaging* — links, frontmatter, an installer path only exercised on updates — went
through none, because none existed. The 2026-08-03 self-audit had already said *"do not roll the
suite into the applying projects yet."* That was still the correct verdict on publication day, and
nobody re-read it.

**The pattern holds all the way down:** an artefact checks whether the work is right. It cannot
check whether anyone asked it to run.
