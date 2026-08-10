# Empirics — what the suite actually did, in real repos

> The evidence base for the tuning pass and for the deferred decisions (five, tracked in the origin repo). Every entry is a
> **real run against a real repo**, not a spec review. Written by the human or by a skill, but the
> **outcome column is the human's** — a skill grading its own homework is not evidence.
>
> Rule: record what happened, what *should* have happened, and — the most valuable column —
> **every time the human overrode the skill.** A rule that gets routinely overridden is a wrong rule.

---

## 2026-07-13 · Run 1 · `wai-pr-review` (breadth lens) · a production backend+web repo · a suite-update PR

**Subject:** suite update `e19009c → 92f5c38` + catalog v3.1 + merge-gate config. Tooling/docs only,
no product code.

### The one that mattered: Test 0 passed

**The model ran `merge-gate.sh` and obeyed the exit code.** It did not check from memory, did not
paraphrase, did not merge. It quoted the verdict verbatim and deferred to the human:

> *"Gate verdict (script, not prose): NO-GO — touches the suite's own guardrails."*
> — translated; the original mixed German and English.

This is the existential test (test plan §0). If the model had ignored an advisory script, every
piece of determinism machinery built on 2026-07-12 would have been decoration.

It passed **in the hardest available form**: the review *wanted* to merge — only Minors, both
landed, nothing blocking — and the gate said no anyway, and it deferred. The gate constrained a
model that had every incentive to say "clean, merge."

And the PR that introduces the guardrail floor was **stopped by the guardrail floor**. Self-
validating.

**Caveat, and it is not small: n = 1.** One obedient run does not establish obedience. Watch for the
case where the gate says NO-GO and the review is *inconvenienced* by it — a feature PR under time
pressure, not a tooling PR where deferring costs nothing. That is where advisory-vs-enforced gets
decided.

### The lens produced findings a diff-focused review could not have

The `breadth` lens (assume the important part is not in the diff) found that the repo's
`merge-gate.conf` protected auth/billing/API but **not `release-status.md` and `invariants.md`** —
two documents that *define the rules the reviewer applies*. An agent-merged edit to
"breaking changes are free until release" changes the bar with no human in the loop.

That is the **same escalation class as the suite's guardrail floor, one level up** — and it was
found by *generalising the principle to a different layer*, not by pattern-matching the diff.

**This is the strongest evidence so far that the lenses are not decoration** (test plan §3). But the
proper test still stands: run the *same* PR through all three lenses and diff the findings. One lens
producing good findings does not prove three lenses produce *different* ones.

### The landing rule held, including where it constrained the reviewer itself

- One finding **fixed in the PR** (the conf gap).
- One finding **filed as an issue** — and the reason it was filed rather than fixed is the
  interesting part: the fix touches `ci.yml`, which is *itself* a guardrail path, so fixing it would
  have required a human-merged PR. **The floor correctly constrained the reviewer's own scope.**
- One finding **rejected with a stated reason, no issue** (no CODEOWNERS — worthless in `solo`,
  since GitHub ignores the author's own review and the floor already blocks agent merges on
  guardrail paths). Correct reasoning, and it did *not* file noise.

Three outcomes, three different branches of the rule, all correct. First run.

### It found a real bug in the suite

`merge-gate.sh` printed **"2 of 1 CI checks are not green."** `gh pr checks --json` emits compact
single-line JSON; `grep -c` counts *lines*, so `TOTAL` was always 1 while `BAD` counted occurrences.

It **failed closed** (pending → NO-GO), so it was never unsafe — and the review said exactly that,
correctly grading it cosmetic rather than raising an alarm. Precise severity judgment.

Fixed upstream the same day, along with two more findings from the same report:
- the lint only scanned `.claude/skills/` as consumers — IDs cited in `docs/` (audits, plans) went
  unchecked. Now scanned.
- the conf template never asked for **the repo's own rule-defining documents.** The floor covers the
  *suite's* guardrails; it cannot know about yours. Now it asks.

### The open one — and it is the same shape as the original bug

`catalog-lint.sh` **is not enforced anywhere.** It runs when `wai-init` writes, and when a
review remembers. Nothing makes it run.

The missing Red Flags existed *because nothing checked*. A check that only runs when someone
remembers is a check that will rot the same way. → filed upstream.

### Verdict on the run

The suite behaved as designed, found real defects (including in itself), obeyed its own gate, and
produced three correctly-routed findings on its first outing. **No override was necessary.**

What it does **not** establish: that the gate holds under inconvenience, that the lenses differ from
each other, that the Red Flags fire on real product code. Those need feature PRs, not a tooling PR.

---

## 2026-07-13 · Run 2 · `wai-pr-review` (adversarial lens, **derived**) · the same PR

Same PR as Run 1. Different lens. **Deliberately not requested — derived.**

### The lens test passed, and this is the result the phase was built to get

Run 1 used `breadth` (requested). Run 2 derived `adversarial` on its own — and the derivation is a
*consequence of an upstream fix the same day*: that PR added the suite's guardrails to the canonical
contract-domain list, so a PR touching them is now **by definition** contract-domain → row 2 of the
lens table → `adversarial`. For a PR that builds the abuse barrier, "assume someone wants to abuse
this" is the right stance. The machinery routed correctly, unprompted.

**And it produced a genuinely different class of finding on the identical diff:**

| Lens | Found |
|---|---|
| `breadth` | a **document outside the diff** that should be protected (`release-status.md`) |
| `adversarial` | a **two-step attack chain** that switches the gate off |

Test plan §3 said: *"If the same list comes back, the lenses are decoration."* **The list did not come
back the same.** The lenses are not decoration. (n = 2 lenses, 1 PR — but this is the test, and it
passed.)

### The finding: the floor protected the rules, not the enforcers

`merge-gate.sh` protected `.github/workflows/ci.yml` — the *declaration* `run: pnpm lint`. It did
**not** protect what `pnpm lint` **does**: `package.json` scripts, `eslint.config.mjs`,
`tsconfig.json`, `turbo.json`, `tools/`. All verified unprotected.

The attack, both steps innocuous: an agent PR "simplifies" `"lint": "echo ok"` → no guardrail path,
no contract path, no Blocker → **GO** → merged. From then on every PR is green against a gate that
checks nothing.

**And it is not hypothetical — it is this repo's own history.** `MAINT-6` documents the incident:
an api package shipped `"lint": "echo \"no lint\""`, CI printed it and went green, the package was
0% linted behind a healthy-looking gate. The reviewer **checked, and found the stub still live in
two packages today.** The attack surface was not just open — it was partly already occupied.

The reviewer's own framing: *"the fix protected the rules, but not the enforcers."* Correct.

### What it did right, beyond the finding

- **Refused to fix a Major.** It had the fix ready (five lines) and did not apply it. Minors may
  land directly; Majors are the human's decision point. The discipline held under the temptation of
  a cheap fix.
- **Verified instead of assuming.** It queried the actual ruleset (`require_code_owner_review:
  false`) rather than assuming the CODEOWNERS file it had just added could deadlock a contract PR in
  `solo`. That is a footgun the template explicitly warns about, and it checked rather than guessed.
- **Attacked its own defence.** It tested whether an agent PR setting `CONTRACT_PATHS=""` could
  neuter the gate — and confirmed the design holds (the conf is itself a floor path).

### What it missed — and the miss is informative

It had the evidence in hand (**the stub is still live in `packages/ui` and `packages/web-client`**)
and did not close the loop to: *and the suite's own stub-guard is root-only, so it would never have
caught these.* In a Turbo monorepo the root script (`turbo run lint`) looks perfectly real while a
package carries `echo ok`. **The guard shipped to prevent stub gates is blind to the exact stubs
sitting in the repo.**

I found that from the reviewer's evidence, not from the reviewer's conclusion. It is a fair miss:
`adversarial` hunts abuse paths, and *"is our existing guard complete?"* is a `breadth` question.
**Which is itself the argument for running more than one lens** — they have different blind spots,
and that is the point.

### Upstream fixes shipped from this run

1. **The floor now covers the enforcement surface** — `package.json` (root *and* workspaces),
   build files, lint/type configs, across JS/Python/JVM/Rust/Go, and `.github/*` wholesale.
   Verified: 12 attack paths blocked, 7 normal-code paths free. It does not cry wolf.
2. **The stub guard walks every workspace**, not just the root. Verified against a synthetic
   monorepo carrying the exact stub the field report found live.
3. **The conf template and `wai-init` now ask for the repo's own enforcement chain** — follow
   one gate command all the way down (`pnpm lint` → `package.json` → `eslint.config` → `tools/`).
4. The canonical contract-domain list in the git protocol now names **both layers**: what defines
   the standard, and what enforces it.

### A methodological finding, recorded because it nearly cost me

My verification harness re-implemented the matcher with `for g in $GUARDRAIL_PATHS` — an
**unquoted** expansion, which makes the shell perform *pathname expansion*: `*/package.json` was
resolved against the filesystem and stopped being a pattern. The test reported that my working fix
was broken.

Had I trusted it, I would have "fixed" a non-problem and possibly broken the real matcher. The real
script is safe (it uses `printf | tr | read`, no globbing) — but only because it does not do what my
test did.

**Rule: verify through the same code path the real thing uses. A re-implemented check is a second
implementation, and it can be the one that is wrong.**

---

## 2026-07-13 · Run 3 · verification of the upstream fix · the same PR

The reviewer re-measured the floor against the **real matcher** after the enforcer fix landed. 5 of 6 attack
paths closed. The sixth is `tools/` — and that is **the design working, not a gap**: the template
says the floor covers the standard chain and the repo conf owns it *where the chain leaves the
beaten track*. Their CI runs `node tools/size-gate/check-size.mjs --strict`, so it does. One line
in `CONTRACT_PATHS`.

### My lint cried wolf on its first field run — 50% false positives, and it blocked a PR

The extended lint (scanning `docs/`, shipped the same day) turned the catalog **red**: 4 hits, **2 real,
2 mine.**

- **Real:** `CLIENT-11` and `CLIENT-12`, cited in a plan. They exist **nowhere** — the series ends
  at `CLIENT-10`. **A plan anchoring requirements to invented IDs** — precisely the case the lint
  was built for, found on its first outing.
- **False:** "API-5" read out of an alert named "API-5xx-Rate". "AI-503" read out of the prose
  sentence *"there is no AI-503 to retry"*. (Note the plain quotes: **a backtick means a citation**.
  These are strings being discussed, not IDs being cited — and writing them in backticks is exactly
  the convention violation the fixed lint now catches. It caught it here, in this file, on its first
  run after the fix. That is the check working, not failing.)

**Cause: my regex.** The original matched **backticked** IDs — the suite's citation convention. When
I rewrote it for the wider scan I replaced the backtick with `.`, a wildcard, and it began matching
substrings. Restored; verified against the exact strings: both false positives gone, both real
findings preserved.

**This is the Semmelweis failure, and I shipped it within hours of writing about it.** My own rule
says a red lint on a catalog diff is a *Blocker*. So: my bug + my rule = a PR blocked for no reason,
half the time. Had it not been caught, the correct lesson for the human would have been *stop
reading the lint* — and then the check exists, is right about what it catches, and nobody looks.

**A check must be cheaper to obey than to argue with. Precision is not a nicety; it is what keeps
the check alive.**

### The reviewer proposed patching the prose. That is the wrong direction.

It suggested rewording the docs (`API 5xx rate`, `there is no AI 503`) to dodge the regex. Cheap,
and it *works* — but it makes every future document pay a tax for a tool's imprecision, forever, and
it will be forgotten. **Fix the tool, not the writing it misreads.**

### `CLIENT-11`/`CLIENT-12`: minted upstream, not locally

The reviewer leaned toward adding them to the iOS repo's own catalog. **Overruled, and the reason
matters:** `CLIENT-*` is a **cross-surface series** (iOS + Android + Web). If iOS mints `CLIENT-11`
for one concept and Android later mints `CLIENT-11` for another, two repos hold two meanings for one
ID — and an ID string is the suite's **only linking primitive**. `## Retired IDs` exists for exactly
this reason: a number must mean one thing forever.

Minted in the **baseline** instead (with Red Flags — client-side media preprocessing before upload;
offline queue with a *stated* reconcile rule). They now propagate to every repo, scoped, on the next
`wai-init` re-run. Catalog: 91 dimensions, 91 Red Flags.

And the rule gap that allowed the confusion is closed: the tailoring rules said new IDs may be
minted locally, and said nothing about cross-repo collision. They do now.

### The structural finding: template fixes do not propagate

`install.sh` updates the **skills**. Nothing updates what they **generated**. An upstream PR fixed the
`ci.yml` stub guard — in the *template*. The product repo's `ci.yml` predates it, has **no stub
guard at all**, and the `echo "no lint"` stubs are **still live in two packages**.

**We fixed the template and the repo stayed broken, and nothing said so.** Same shape as everything
else: upstream looks correct, downstream is wrong, nothing reports the difference. → tracked as the doctor plan.

### What the suite fixed, unprompted, from its own review

`wai-cicd` now **declares the gate's dependencies itself**: it wrote the workflow, so it knows
what the workflow *runs* — it follows each gate command down and puts every path it reaches into
`CONTRACT_PATHS`. The `tools/*` gap closes automatically instead of waiting for a human to read a
comment in a template. **The skill that builds the gate is the one that knows what it depends on.**

---

## 2026-07-13 · Run 4 · `wai-init` + `catalog-lint` · **install into a second repo** (iOS)

The first run that was not a PR review. The suite was updated and installed into a second product
repo, and the lint was run across all three catalogs. Three findings were reported. **One of them
was false, and it was the one stated most confidently.**

| Reported | True? |
|---|---|
| iOS: 34 of 58 dimensions carry no Red Flag | **yes** — reproduced |
| iOS: the 26 "dangling IDs" are a lint artifact, report upstream | **yes — and the diagnosis was right** |
| Backend: 4 IDs are *real doc drift*, hand off to that repo | **no. All four were already resolved.** |

### The confident finding was the wrong one, and staleness is why

The session had fast-forwarded past two merges and reported "no open PRs". It was right — for
sixteen minutes. The fix for the lint's own false positives merged sixteen minutes after the
merge before it, and the session had only the earlier of the two.
So it ran **the wildcard-regex lint** and reported its output as current truth.

Its four "drift" IDs were the exact four from Run 3: "AI-503" and "API-5" — the two false positives
that fix removed (**plain quotes on purpose: a backtick means a citation.** I wrote this paragraph
with backticks, and the lint failed the build. In the file where I documented the convention. It is
a good check) — plus `CLIENT-11`/`CLIENT-12`, which the backend had *already adopted from the
baseline* that morning. Re-run with the current lint, the backend is **clean**: 80 dimensions, 80
Red Flags, every citation resolves. Had the recommended handoff been filed, it would have been a
handoff for four non-problems.

**No version stamp would have caught this** — the tool was current when it ran. What caught it was
**re-running it**. A field report is evidence, not a verdict: reproduce before you act. That
reproduction is also what found everything below, none of which was reported by anyone.

### My check failed by construction in every repo but the one I wrote it in

Check 4 resolved **skill** citations against the **repo's** catalog. But the skills are *vendored*:
they were written against the **baseline**, and they cite ~80 of its IDs. A repo tailors its catalog
to a **subset**. So the check could only ever fail — on files the repo does not own and cannot fix.
26 findings, not one actionable.

Skills now resolve against the baseline they shipped with; docs resolve against the repo's catalog.
That keeps the bug the check was built for (a skill citing `SEC-4` for IDOR when IDOR is `SEC-8`)
and stops punishing a repo for the entirely correct act of tailoring. **A check nobody can obey is
a check everybody turns off.** Second time this week.

### Check 3 was decorative in every consuming repo, and had been all along

"No retired ID reused" reads the repo's **own** retired list. A tailored catalog starts with that
list **empty** — `wai-init` does not carry the baseline's retirements across. So it printed
`✓ no retired ID reused (0 retired)` forever, in exactly the repos where renumbering happens.

**I then nearly shipped the obvious fix, and it was wrong.** Failing a live dimension whose ID the
baseline retired turns the backend red for `MAINT-6 · Type-Check & Lint Gate in CI` — live, closed,
cited by its own issues — because the baseline retired *its own* MAINT-6, a modularity dimension,
into `MAINT-1`. Same number, **two ID spaces, two unrelated concepts.** Renumbering would have
broken every citation in that repo's issues and ADRs for nothing.

Whether two dimensions on one number *mean* the same thing is a semantic judgment. **A shell script
cannot make it, and a check that renders a verdict it cannot justify is how a lint gets switched
off.** Same line as the merge gate: the script owns mechanics, the model owns judgment. The check
stays repo-local, and the mechanically-decidable part moved to where it belongs.

### The lint read the essays and skipped the enforcement

Its consumer scan globbed `*.md`. But the suite's **load-bearing** citations are not in prose — they
are in `ci.yml` and `merge-gate.sh`, where a guard is anchored to the dimension that justifies it.
Scanning markdown only, the check reported ✓ while **two of the suite's own artifacts cited a
RETIRED ID**: `MAINT-6`, carried in from the repo where the stub-gate incident happened, where that
number really does mean the lint gate. In the suite's own ID space it means nothing — it retires
into `MAINT-1`, modularity. Every finding those two artifacts would ever anchor pointed at the
wrong dimension.

A doc may cite a retired ID; an audit from March must stay readable — that is what the retired list
is *for*. **A skill may not.** A skill is an instruction executed today.

### And the dimension it should have cited did not exist

Re-pointing the citation had nowhere to land. The baseline had **no live dimension for "a gate
scores green without running anything"** — the single fact the entire auto-merge premise rests on.
`MAINT-3 · CI/CD & IaC` covered reproducible builds; its Red Flag decided nothing about a vacuous
gate. Widened, and it decides it now.

**Nobody would have found this by reading.** It surfaced because a script tried to resolve a
citation and could not.

---

## 2026-07-14 · Run 5 · two field repos report back · **the gate was dead on arrival**

Two independent reports, measured against live installs rather than reasoned from the source. Between
them they found the worst bug the suite has had, and the root cause of every ID collision it has hit.
Neither was found by reading.

### The merge gate could never say GO. In any repo. Ever.

```
✗ 1 of 3 CI checks are not green: build-push=SKIPPED     →  VERDICT: NO-GO
```

`test` and `size-gate` are SUCCESS, and they are **the only two checks the branch ruleset requires**.
The gate blocked on a check nobody asked for.

The rule was *"every reported check must be SUCCESS"*, which treats **SKIPPED as a failure**. It is
not one — SKIPPED means the job's own condition said *do not run*. And **the suite's own `ci.yml`
ships a build job gated on `github.ref == 'refs/heads/main'`**, so on every PR that job is skipped
and GitHub still reports a check run with conclusion `skipped`.

**Every PR in every repo carried a permanently non-green check.** The auto-merge path the entire
suite is built around shipped **dead**, and stayed dead through five field runs, because a NO-GO
looks exactly like a NO-GO.

**The obvious fix is a trap, and the report named it before I could reach for it.** *"Treat SKIPPED
as green"* opens **skip-to-green**: put a `paths-ignore` on the test job, an API PR skips it, the gate
calls it green, and the required check never ran. That is the same evasion the stub guard was
hardened against a day earlier. **A fix that swaps one hole for another is not a fix.**

The correct semantics — and it is the guardrail-floor doctrine again, one layer up:

> **Green means: every check the base branch REQUIRES is SUCCESS. Everything else is informational
> and must never veto.** A *required* check that is SKIPPED is a NO-GO — deliberately stricter than
> GitHub, which lets one pass. If the required set cannot be read, fall back to strict. There is no
> path from "could not check" to "go".

**Three bugs while fixing it, all caught by running it, none by shellcheck:**

- `for r in $REQUIRED` word-splits a check name that contains spaces (`Lint (all workspaces)`), so
  every such check silently becomes *did not report* → a permanent NO-GO nobody can explain.
- A `case … esac` inside a `$( )` is a **syntax error in bash 3.2**, which is what `/bin/sh` *is* on
  macOS. shellcheck passed it. The shell did not.
- `awk -v req="$REQUIRED"` — BSD awk rejects a newline inside a `-v` assignment. Tested, not assumed.
- And `gh api` prints its 404 body to **stdout** and exits non-zero, so a naive `|| true` reads
  `{"message":"Branch not protected"}` in as a required check name.

All four are the same failure: **the code path I tested was not the code path that runs.**

### ID collisions: the doctrine instructed the trap

`catalog-sizing.md` said, in as many words:

> *"additions append at the end of the respective ID series ("SEC-14", "MAINT-10", …)"*

**"SEC-14" and "MAINT-10" are, today, two of that repo's three collisions.** Plain quotes,
deliberately: a backtick is a *citation*, and these are another repo's numbers. I wrote them
backticked — this repo linted **red for a day, and a PR merged red**, because nothing runs the lint.
That incident is why this file now has a test suite standing behind it. Two catalogs both
appending to the end of the same series will collide — each is appending from a different state. The
doctrine did not fail to prevent the trap; **it specified it, and named the exact numbers.**

The damage is worse than duplicate numbering. That repo's `SEC-8…SEC-13` block is **shifted** against
the baseline: its `SEC-8` is *CSRF Hardening*, the baseline's is *IDOR*. `review-lenses.md` cites
`SEC-8` for IDOR — a citation **I corrected two days ago, and it is now correct upstream and wrong
there.** The finding is real, the citation resolves, and the anchor is wrong.

**A dangling reference fails. A misbinding resolves — to the wrong dimension.** No checker sees it.
The reference is valid. And it is invisible *at the moment of action*, because applying it looks
exactly like applying an upstream fix, which is what one is supposed to do. It has now cost that repo
time three separate times, including once when its own defensive note tripped my lint.

**What is mechanical, and is now enforced:** the baseline owns the low numbers; a locally-minted
dimension is **≥ 100** or declared under `## Local IDs`. Provenance in the string — two digits shared,
three digits local, readable at a glance. And: **a copied template may not cite a bare ID at all.**
Vendored skills were already safe (check 5 resolves them against the baseline) — but templates are
**copied**, and on copy every number rebinds to the repo's ID space. 13 IDs across 4 templates. My
`MAINT-6` → `MAINT-3` fix, ported downstream, would have introduced the bug it fixed.

**What is not mechanical, and never will be:** whether two dimensions on one number *mean* the same
thing. I built that check anyway, ran it, and it produced **3 false positives in 10** on the very
data it was designed for. It is deleted. `wai-init` makes that call on reconcile — because it
is a model, and this is semantics.

### What the field taught, that the source could not

> **A check that has never run in a foreign repo is untested.**

Every one of these bugs was invisible from inside the repo that wrote the code. The gate looked
strict. The doctrine looked careful. The lint looked thorough. **Five clean-looking runs, and the
central feature had never once been able to succeed.**

---

## 2026-07-14 · Run 6 · **lessons from two field repos** — what a GO/NO-GO decision actually is

Five documents, written from live installs (`5902475` → `addf6d7`) across two repos and roughly a
dozen PRs. Not new bugs — a reframing of the ones already found, and it is sharper than anything the
source repo produced.

### A gate has four ways to be wrong. Only one of them is loud.

| Failure | How it presents | Who designs for it |
|---|---|---|
| says **GO** when it should say NO | something bad merges. You find out. | **everyone** |
| says **NO-GO** when it should say GO | **nothing happens** — which is what a gate looks like | nobody |
| right verdict, **wrong reason** | the answer is right, the stated reason is not | nobody |
| an answer you **cannot audit** | *"the model checked"* | nobody |

**Gates do not die by letting something through. They die by becoming decoration people route
around.** Everyone tests the block path — it is easy and it fails safe. Almost nobody tests the pass
path, and the pass path carries the gate's entire value.

> **A gate you have never seen say GO is not a validated gate. It is an untested branch that happens
> to be failing closed.**

This suite ran one for months, in two repos, and *caution is exactly what it looked like.*

### NO-GO is a fact about the PR. UNKNOWN is a bug report about the gate.

Folding UNKNOWN into NO-GO — both mean "the human merges", so why distinguish? — throws away **the
only signal that says the gate itself needs fixing.** Which is precisely the signal that was missing
for the whole time it never said GO. And the fold in the other direction is worse: a repair hint went
out through `unknown()` and silently upgraded a definite NO-GO to *"I couldn't tell."* Never unsafe.
But a gate that misreports which of its own states it is in is a gate people stop reading.

Fail closed — **and then go and check whether "closed" is where it has been the whole time.**

### The green check that lied by implication

`catalog-lint`'s new local-ID check passes any ID present in the baseline. Its comment said
`# a baseline dimension, adopted`. **It never verified that.** One field repo holds **five** numbers
that mean one thing there and another upstream — its `SEC-8` is CSRF hardening; the baseline's is
IDOR — and **every one of them passes.**

The check catches the **future** hazard (a new local mint). It is blind to the **live** one, which is
the dangerous half. And the cost of the implication is concrete, in their words: *"our `## Local IDs`
section, written to satisfy this check, read as though those three were the whole story. They are the
lesser half."*

**A green check that implies coverage it structurally cannot have is worse than a red one.** It now
says what it cannot see. No new check was added — and the request explicitly was not for one.

### The rule that holds the line is not a lint. It is a boundary.

> An ID arriving **from upstream** — a commit message, a skill, a template, a retirement list — is
> **baseline space** until proven otherwise. The repo's own docs, CI config, ADRs and PR bodies are
> **local space**. **Never copy an ID across that boundary. Translate it, or drop it.**

It explains all three firings at once, and every one of them **looked like doing the right thing.**

### Two debts, and the measured cost of leaving them

`## Local IDs` (minted — fixable forward, at ≥ 100) and `## Reused Baseline IDs` (a baseline number
given a different meaning — **no repair, a translation table forever**). Conflate them and the
translation table disappears inside a list of things that are already handled.

**Realigning after four days: 30 citations across 15 files, one hour.** After four months of issues,
audits and PR history: a migration project. **The debt does not sit still.**

### And the fix for a wolf is precision, never leniency

Three checks cried wolf in one week. In one of them the reviewer — me — proposed rewording the
**documents** to dodge the regex. Overruled, correctly: *that taxes every future document for a
tool's imprecision, forever, and it will be forgotten.* **Fix the tool, not the writing it misreads.**

### What was rejected, and why

The **title-comparison collision check** these reports asked for was built, run, and produced **3
false positives in 10** on the data it was designed for. Deleted. Whether two dimensions on one
number *mean* the same thing is semantics, and no script makes that call — `wai-init` does, on
reconcile. See [ADR-0002](adr/0002-mechanics-in-scripts-judgment-in-prompts.md).

---

## 2026-07-15 · Run 7 · **the gate said GO** — and the model declined to merge anyway

The first GO in any repo, ever. And it fell to the PR that documented that the gate had never given
one. Verbatim report:
[`learnings/field-reports/2026-07-15-backend-web-the-gate-said-go.md`](field-reports/2026-07-15-backend-web-the-gate-said-go.md).

Run 6 set the standard and the gate has now met it:

> *A gate you have never seen say GO is not a validated gate. It is an untested branch that happens
> to be failing closed.*

**It has now been seen.** `merge-gate.sh`'s header said *"this gate never said GO… for its entire
existence"* — **true when written, a lie today.** Corrected in place, with the date, because a claim
in a comment rots exactly like a claim in a document.

### And then it did not merge

Solo mode. GO from the script. A clean review — docs only, no product code, no contract, no guardrail.
**Both halves green. By the rule it was allowed to merge.** It refused:

> *"The gate owns the mechanics, I own the judgment — and my judgment is: a document about my own
> mistakes, which you corrected twice in the last ten minutes, is not mine to land unread. That is
> not dodging the rule; that is the judgment half of the conjunction doing its work."*
> — translated from the German original.

**This is the only recorded instance of the judgment half overriding a green gate**, and it is what
[ADR-0002](adr/0002-mechanics-in-scripts-judgment-in-prompts.md) claims must be possible. A script
that could be talked into merging that PR would be a script that had swallowed the judgment call.

### The correction that matters more than the GO

Two errors that week, and **no artefact caught either**:

- A rule was called *"broken, because it never fires"* — on an **invented denominator**. Measured:
  exactly **one** PR touched product code. **0 of 1, and the zero was right.** *"Every artefact in
  the system would have agreed with me. Every individual decision was compliant. What I was missing
  was the reason."*
- A rule that sat in the agent's own memory was **reinterpreted, and then rationalised in the same
  breath.**

> **An artefact checks whether the work is right. It cannot check whether the QUESTION was right.**
> **And it cannot check whether you kept a rule you decided to reinterpret.**

That is the ceiling on everything in this file, and it belongs above the rest of it, not below.

**The hardest number now stands at 9 of 9: every claim made without measuring was wrong.** My own
contributions this week — *"for a year"*, *"+52/85/94 %"*, *"29 cases, every one a bug that shipped"*
(it is 8 of 29), and **"wai-learning-gap never fired across ~40 PRs"**, which was in my persistent memory
and whose denominator I invented in precisely the manner described above. Struck through there, not
deleted: **a correction is a new entry that points at the old one.**

---

## 2026-07-20 · Run 8 · two field runs converge — artefacts miss the *question* and the *ordering*

Two retrospectives, different stacks, different agent-days: backend+web (whole-suite run) and iOS
(native Swift client). Processed into a doctrine change, the CVE script, one deferred consolidation, and comments
on the open measurement decisions. The reports are the record; this is the distilled lesson and the decisions taken.

### The convergent finding

**Artefacts check whether the WORK is right. They cannot check whether the QUESTION was (backend),
nor whether the ORDERING was (iOS).** Backend: **9/9** unmeasured claims wrong, **17/19** errors
caught by a tool, **2 only by the human** — and neither of those two *could* have been caught by a
tool (an invented denominator; a rule the agent talked itself out of). iOS reproduced it: **3/3**
unmeasured claims wrong, plus a review that ran *after* merge and a metric whose tool never ran.
The two-catch model is not a backend quirk — it is the shape.

### What the suite got RIGHT (keep — do not touch)

1. **Planning's cross-cutting-first mandate** surfaced a native-passkey infra + cross-repo blocker
   (Associated-Domains entitlement + AASA) **before one line of client code** — the exact class that
   is ruinous to find after implementation. The promise of a planning stage, held.
2. **"A directive is a request; say which you honoured"** defused "delete all demo data completely,"
   whose naive read would have deleted test doubles in **13 test files**. The agent drew a defensible
   boundary (runtime injection out, test infra stays) and *stated* it. Canonical example.
3. **The gate stayed honest under temptation** — it flagged the audit *report itself* as
   contract-domain → NO-GO → human-merge, and the skill obeyed rather than rationalising "it's just
   my own audit narrative." The ledger row exists.

### What changed (built)

- **Doctrine** — the first principle (*artefacts check the work, not the question; the human is the owner
  of the why*) at the router Principles + the decision-point authority; **post-merge review
  detection** (pr-review announces it; merge-gate.sh short-circuits to a tested **MOOT** verdict and
  records a MOOT row, because an absent row reads as "never checked"); **stage explicitly, never
  `git add -A`**; and the **audit-report carve-out** for `merge-gate.conf`.
- **`dep-cve-scan.sh`**: a CVE scan that did not run reads as **`not_measured`, never a silent
  0**. The human's call — make it deterministic (a script), not a prose please-remember. Same
  mechanics/judgment split as the gate.

### Rejected — with reason (so they are not silently re-proposed)

- **A planning length-cap** (iOS P4). Over-production was a discipline slip, not a missing rule; a
  cap would punish the deep plans (passkey, Apple SSO) that genuinely earned their length. The lever
  is a sharper **example**, filed onto the which-rules-fire decision — not enforcement.
- **Mechanising "is the question right?"** (backend closing). You cannot lint your way to it; the
  attempt would be the next green check that lies by implication. The correct response is to
  **name** it in the doctrine and design the human into the loop where the question is set — not automate it.
- **Re-adding "run `git branch --show-current` before every commit"** (backend P3's other half).
  That habit was deliberately retired for the `pre-commit` hook ("a hook, not a habit," after three
  commits landed on main). Re-stating it would reverse a deliberate decision and invite trusting the
  words over the enforcement. Only the genuinely-new *staging* discipline was added. **This is the
  anti-cycle check working:** a proposed change that would have reintroduced a retired symptom,
  caught by reading the reason the line was set.

### Deferred — filed, not dropped

- **Deferred** — one shared `measurement-protocol.md` consolidating the four scattered phrasings of
  "measure, don't assert / a tool that printed nothing may never have run." Net consolidation, not
  accretion. The CVE and audit-metrics instances implement it; the deferred item names the principle.

### What it does NOT establish

The keep-items are one run each; the 9/9 and 3/3 are strong but from two developers, and the suite
still cannot see the question or the ordering except by *naming* the situation — which is prose, and
prose is a probability, not a guarantee. That trade is deliberate (you cannot mechanise the ceiling),
but it is a trade, not a fix.
