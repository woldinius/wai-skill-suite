# How this suite came to be

A development history — what was adopted when, and just as deliberately, what was dropped and why.
Every claim below is backed by a dated artefact in this repo: the [ADRs](adr/), the
[empirics ledger](empirics.md), the [field reports](field-reports/), the
[July retrospective](retrospective-2026-07.md) and the [first structural audit](architecture/audits/2026-08-03.md).

> **Disclosure.** This repository is a **curated re-publication**. The suite was developed in a
> private repo whose history carries product names and German drafts that
> have no business being public. The milestone commits here carry the **real dates** of the work
> (times normalized to 00:00 UTC) and introduce the components in the order they actually arrived —
> in their final, cleaned form, not as byte-exact snapshots of the day. The dated documents under
> `docs/` migrated with their content intact; translated field reports say so, and the German
> originals remain in the private archive. **Every timestamp in this repo is date-only, by rule** —
> see [time normalization](time-normalization.md); the one exception is what GitHub itself stamps.

---

## Prehistory: December 2025 – June 2026 — a wild set of similar skills

The suite did not start as a suite. Starting in **December 2025**, early versions of individual
skills — an implementation skill under a different name, review helpers, planning prompts — grew
inside the product repos they served: several production projects and prototypes, each carrying
its own slightly-diverged copy. By **May 2026** another product repo had joined, with the same
pattern: skills that looked alike, drifted apart, and were fixed in one place but not the others.

That divergence is the founding problem. A rule that lives in four copies is four rules.

## 2026-06-13 — Consolidation: the scattered skills become one suite

The first commit of the master repo consolidates the strongest of those scattered skills into one
place: **pr-review**, **requirements-planning**, **init**. From this day on the suite is a single
source of truth, adopted *into* the product repos rather than grown inside them — and it has been
in daily use across several projects ever since. Publication changes the audience, not the usage.

## 2026-06-27 — The router, the git flow, the first gate

A **router** skill becomes the front door; **testing** and **architecture-audit** join; and the
**agent git protocol** lands: work happens on `agent/**` branches, a human merges, `main` is
protected. The first merge gate exists — as prose a model was asked to remember. That design
decision will be reversed sixteen days later, and the reversal is the most important event in
this file.

## 2026-06-28 — Four equal surfaces and the contract spine

The suite reframes around a **multi-surface product**: cloud backend, web, iOS, Android — four
first-class surfaces joined by a versioned **API contract** ([contract protocol](../.claude/skills/wai/references/contract-protocol.md)).
**mobile-release**, **implementation** and **cicd** complete the lifecycle;
GitHub-Issues awareness ties findings to a durable tracker instead of a chat.

## 2026-07-09 — The lifecycle completes; the first reversal

One day adds **learning-gap** (personal, opt-in, never repo-wide), the **team** orchestrator
(mandate-based batch work), the **security audit** (split out of the architecture audit because
adversarial and structural are different questions), the **grilling** and **issues** protocols,
and the idempotent **installer**.

**Dropped the same day:** Coolify as the deployment target. The cicd skill became **GitHub-native
by design** — Actions, GHCR, Compose over SSH — because one opinionated, tested path beats a
matrix of half-tested ones. That narrowing was a choice, and it still stands.

## 2026-07-11/12 — Multi-developer safety; the suite leaves home

Branches gain an **owner segment** (`agent/<handle>/…`), issues are **claimed** before they are
built, and the catalog learns **sizing** (scope × tier) — because the catalog is read on every
lifecycle run, its size is the suite's biggest cost lever. **Review lenses** arrive
(breadth · adversarial · null-hypothesis). The suite is decoupled from its origin repo and becomes
English-only.

## 2026-07-13 — The reversal that defines the suite: mechanics move into scripts

A deep self-audit finds: **55 of 89 catalog dimensions had no Red Flag — and nothing checked.**
Every skill was told to "look up the Red Flag for ID X"; when a model is told to look up something
that is not there, it invents a standard for the session or silently drops the finding — and a
clean review looks identical either way. Two of the missing dimensions were marked *mandatory* in
the suite's own testing strategy.

The conclusion became [ADR-0002](adr/0002-mechanics-in-scripts-judgment-in-prompts.md): **what is
mechanically decidable moves out of the prompt and into a script with an exit code.** The merge
gate becomes `merge-gate.sh` — `0 GO · 1 NO-GO · 2 UNKNOWN`, fail-closed, no path from "could not
check" to "go". The catalog gets `catalog-lint.sh`. The same day, a field run shows the gate
**stopping the very PR that introduced it** — the review wanted to merge, the gate said NO-GO,
the model quoted the exit code verbatim and deferred to the human
([empirics, Run 1](empirics.md)).

**Dropped, deliberately, in the same period:** two scripts that crossed the line. A cross-catalog
collision check turned a repo red that was right; a title-comparison heuristic scored 3 false
positives in 10 on the very data it was built for. Both deleted. *Whether two dimensions on one
number mean the same thing is semantics* — and semantics stays with the model. The boundary is a
position, not an accident.

## 2026-07-14/15 — Determinism gets its bill

The scripts that decide everything turn out to be deciding wrongly: the gate had **failed open**
under zsh, then **could never say GO** in any repo (it read SKIPPED as failure). Nine repair
commits in two days. The consequence is `tests/` — every case a bug that shipped — on **two
shells**, because shellcheck passed a construct that is a syntax error in bash 3.2, which is what
`/bin/sh` is on macOS. *Determinism does not buy safety. It buys testability — and then you have
to actually test.*

The same week, the git protocol's rules stop being prose too: after three violations
("work happens on a branch" broken three times; three pushes onto branches whose PR was already
merged, one of them a **security fix**, where every signal came back green), `.githooks/pre-commit`
and `pre-push` make the failure loud. The gate starts writing its own **ledger** — the
denominator for every later "this rule never fires" claim.

## 2026-07-21 — The ceiling gets named

A doctrine change writes down what no artefact can do: **an artefact checks whether the work is
right; it cannot check whether the question was right** — proven by an agent that called a rule
"broken, because it never fires" on an invented denominator (measured: 0 of 1, and the zero was
correct), and by a rule an agent reinterpreted for itself. Both caught by the human, neither by a
tool. `doctor.sh` starts reporting repo drift at update time; the CVE gate learns that a scan
that did not run must read as **not measured, never silently clean**. A 27-agent
[tooling analysis](proposals/2026-07-21-suite-tooling-analysis.md) maps where scripts could cut
randomness across all twelve skills — and an adversarial "creativity guardian" in that workflow
kept judgment calls out of the script column.

## 2026-08-02/03 — The field batch

Nine [field reports](field-reports/) from production repos and a prototype land in one wave, and
force fixes in both directions:

- a **tool failure is not a verdict** — the gate reported NO-GO where it should have said
  UNKNOWN (a dead remote), and the distinction is what keeps NO-GO believable;
- a **review that stays in the chat did not happen** — the verdict now belongs on the PR, on
  every path;
- `Closes #N` **only fires on the default branch** — a repo setting no skill had checked;
- the suite's own lint had been **red for twelve days** on findings that were opinions, not
  defects — unreproducible locally because the runner's shellcheck was older than the
  developer's; the lint now reports defects only, and the lesson is structural: *a signal that
  never flips is not a signal*;
- the learning-gap hook **blocked the suite's own test fixture**; issue mining **fragmented
  German words at umlauts** — found because the suite runs in non-English repos, not despite it.

The first [structural self-audit](architecture/audits/2026-08-03.md) measures the suite against
its own baseline — verdict: *significant drift*, fifteen findings from one seam — and the two
blockers are closed the same day. The audit is the suite's own medicine, taken.

## 2026-08 — The `wai` namespace and this repository

The suite claims a vendor namespace: `platform-*` becomes **`wai-*`** — `platform` was a claim on
a generic English word that collided with what users would plausibly name their own skills, and
two skills with near-identical names is the documented way to make routing fail. The installer
migrates existing installs (prune by manifest, never by name), the docs you are reading are the
cleaned evidence base, and the milestones above become this repository's commit history.

## 2026-08-05 — The first cold checkout, and the day prose broke three times

A cold reader checked out the published repo and filed **three blockers in one day**, every one a
rule nothing checked: the installer's documented update path destroyed the skills it was updating,
the only skill with valid YAML frontmatter was silently losing 61% of its description to a `#`
comment, and the README's Evidence section — the part carrying the honesty claim — was made
entirely of dead links. All three were closed the same day, each with a test that is red against
the pre-fix tree ([first-checkout report](field-reports/2026-08-05-first-checkout-review.md)).

Then the fix batch **misreported itself** — a finding marked Fixed that was half-done, a commit
message asserting history that `git show` refutes, and fresh install instructions pinned to a tag
that did not exist — and the batch fixing *that* repeated the pattern once more, one level deeper
([corrections report](field-reports/2026-08-05-second-review-corrections.md), including its own
addendum). Three iterations of one class in one day bought three mechanisms: the repo's
English-only rule became `tests/lang-guard.sh`, this repo's **gate ledger wrote its first real
row** (a NO-GO, human-tagged `ok` — until then its own gate claims were anecdotal, issue #9), and
the class itself got its check: `tests/numbers-lint.sh`, which measures every mechanically
checkable count in living prose — including whether a referenced release tag exists.

---

## What the record says, in one paragraph

The suite's shape was not designed up front; it was **forced by failures that are all on file**.
Prose rules failed silently → scripts with exit codes. Scripts failed loudly → tests on two
shells. Checks cried wolf → precision, never less strictness. Two scripts crossed into judgment →
deleted. And two errors no artefact can catch — a wrong question, a reinterpreted rule — put the
human permanently at the top. The ordering *tool where decidable, model where judgment, human
where neither suffices* is not a philosophy the suite started from. It is what was left standing.
