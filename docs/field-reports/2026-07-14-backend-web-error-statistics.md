# Error statistics — one week, two repos, 47 defects

**Source:** a production backend+web repo, running the suite from `5902475` → `e04448e`
**Date:** 2026-07-14
**What this is:** a count, not a story. Every number below points at a specific incident. Nothing is
rounded up, nothing is inferred. Where I could not point at the incident, I did not count it.

**Why it exists:** the suite already collects *what broke*. This collects **who was wrong, how often,
and what caught it** — because the answer to the third question turned out to be the only one that
matters.

---

## The headline

> **Of 8 technical claims I made without measuring, 8 were wrong.**
>
> **Of 47 defects found across the week, 0 were found by thinking. Every single one was found by an
> artefact that ran and disagreed.**

Everything else in this document is elaboration on those two lines.

---

## 1. The agent's errors — 17

Broken down by **what caught them**, because that is the finding:

| Category | Count | Caught by |
|---|---|---|
| Technical claims asserted without measuring | **8** | Running the thing |
| Craft errors | 5 | Tests, linters, the IDE, `grep` |
| Judgment / process errors | 4 | The gate itself; re-reading my own work |

**Zero were caught by reasoning about them harder.**

### 1a. The 8 that measurement refuted — and I got 0 of 8 right

| # | What I asserted | What measurement showed |
|---|---|---|
| 1 | "Alpine's `imagemagick` is a minimal build — the ImageTragick class is off the table" | It ships `gslib`, `ps`, `rsvg` delegates and the `MSL`/`MVG`/`PSD`/`HTTP(S)` coders |
| 2 | "A PS-**write** probe proves the policy is in effect" | Wrong threat direction entirely. The threat is **reading** hostile uploads. The probe would also have passed vacuously. |
| 3 | "SVG and MVG are already refused without a policy" | **`magick mvg:<file>` decodes by default.** ImageTragick's core vector, wide open. |
| 4 | "An HTTP e2e will prove the EXIF strip" (I wrote this into my own DoD) | Impossible. `build-test-app` replaces the **whole** `AiService`, and `prepareForVision` is called inside it. The test would have gone green with the feature **ripped out**. |
| 5 | "Do the gate PR first, then the image PR" | The gate PR depended on `catalog-lint.sh`, which did not exist on `main` yet. Wrong sequencing. |
| 6 | "The coder allowlist blocks the PS coder" | It does not block PS **writes** at all. |
| 7 | "Reword our documents to dodge the lint's regex" | Overruled upstream, correctly: *that taxes every future document for a tool's imprecision, forever, and it will be forgotten. Fix the tool, not the writing it misreads.* |
| 8 | "Delegate `CLIENT-11`/`CLIENT-12` to the iOS repo's catalog" | Overruled upstream, correctly: `CLIENT-*` is a **cross-surface series**. Two repos minting one number for two concepts is exactly the collision an ID exists to prevent. |

**The symmetric observation:** every single time I *measured*, the measurement found something I had
not predicted — the 16.4 GP default resource ceiling; that MVG decodes; that the worker and the API
share one image; that the e2e mock boundary sits **above** the code under test.

### 1b. Craft errors — 5

| # | Error | Caught by |
|---|---|---|
| 9 | `#` comments inside a Dockerfile `RUN` continuation broke the parser | IDE linter, instantly |
| 10 | A Python extraction pulled `MAX_THUMBNAILS` and `PdfPreview` into the wrong module | `grep` |
| 11 | Adding an `execFile` timeout broke the test mock (the callback moved to argument 4) | The test I had just written |
| 12 | My **verification harness** re-implemented the gate's matcher with an unquoted glob and confidently reported a **working** config as broken | Re-running through the real code path |
| 13 | A nested heredoc (`python3 … \|\| node …`) inside a Dockerfile `RUN` — abandoned | Trying to build it |

**#12 deserves its own line.** I nearly "fixed" a non-problem because *my test was the thing that was
wrong*. The rule that falls out — *verify through the code path the real thing uses; a re-implemented
check is a second implementation, and it can be the one that is broken* — I then watched the suite's
own author hit the identical trap, independently, in the same week.

### 1c. Judgment and process — 4

| # | Error | Consequence / catch |
|---|---|---|
| 14 | A `git add -A` swept an update to **`merge-gate.sh` itself** into a security PR | Caught by the **guardrail floor** — i.e. by the machine, not by me. A change to the thing that decides which PRs may merge nearly travelled inside another PR. |
| 15 | I wrote a `## Local IDs` section that **told half the truth** — it presented the *lesser* debt (numbers we minted) as the whole story, omitting the worse one (numbers we **reused**, which no lint can see) | Caught only on a **second reading**, after it had already survived a full review cycle — **my own**. |
| 16 | My own Definition of Done demanded a proof that was structurally impossible (see #4) | Caught while trying to satisfy it |
| 17 | A Python string-replace mangled the memory file, concatenating stale text mid-document | Caught by reading the result; had to be rewritten |

---

## 2. The suite's own defects — 16

And the sharpest statistic of the week:

> **The two scripts that decide everything needed 15 revisions in 19 upstream commits.**
>
> `merge-gate.sh`: **8 revisions** · `catalog-lint.sh`: **7 revisions** · 10 of 19 commits were `fix`.
>
> **The tools that judge correctness were the least correct things in the system.**

Selected, in descending order of how badly they undermined the thing they existed to do:

1. **The gate never said GO.** Not once, in two repos, for its entire existence. `SKIPPED` counted as
   a failure; every repo has a build-on-main-only job; therefore every PR carried a permanently
   non-green check. The auto-merge path — *the reason the gate exists* — shipped **dead**, and nobody
   noticed, because "no" is what a working gate looks like.
2. **A repair hint emitted through `unknown()`** silently **upgraded** a definite NO-GO into "I could
   not tell". The gate misreported which of its own three states it was in.
3. **`"2 of 1 CI checks are not green"`** — `grep -c` counting lines of single-line JSON. A human read
   that nonsense number and shrugged.
4. **The floor did not protect itself.** An agent could merge a change to the standard it was judged
   against.
5. **The floor protected the rules but not the enforcers.** `ci.yml` protects the *declaration*
   (`run: pnpm lint`); it does not protect what `pnpm lint` **does** — `package.json`, the eslint
   config, `tools/`. Two innocuous-looking PRs and the gate checks nothing.
6. **`catalog-lint` did not exist**, and so 55 of 89 baseline dimensions had no Red Flag — for a year.
   Nobody noticed, because nothing checked.
7. **The lint then cried wolf at a 50 % false-positive rate** — reading `API-5` out of an alert named
   `API-5xx-Rate` — and by its own rule (*a red lint on a catalog diff is a Blocker*) **blocked a PR
   for no reason**.
8. **Its check 4 failed *by construction* in every consuming repo** — 26 findings, none actionable, on
   files the repo neither owned nor could fix.
9. **A green check lied by implication** — the local-ID check passes any ID present in the baseline,
   and its comment said *"a baseline dimension, adopted"*. It never verified that.
10. **The stub guard was root-only** in a Turbo monorepo, where the root script is a delegator that
    looks perfectly real. It was blind to the exact stubs sitting in the repo.
11. **The stub guard failed honest work** (`vitest run && echo ok`) — and a guard that fails honest
    work is a guard people delete.
12. **The exit-code swallower** (`eslint . || true`) sailed straight through it: a real linter, real
    findings, and it can never fail. The stub that *looks* real.
13. **`install.sh` destroyed a user's own skill** on its first run, inferring ownership from the name.
14. **`wai-init` wrote the catalog before asking the questions that configure it.**
15. The router promised a PR that planning is forbidden to open.
16. Both audit playbooks assumed `pnpm` — in an npm repo, every tool silently "not measured this run".

---

## 3. The consuming repo's pre-existing defects — 14

Found *because* the tooling finally ran. Selected:

- **36 of 83 catalog dimensions had no Red Flag** — the same disease as the baseline's 55/89, same
  cause: nothing checked.
- **`apps/api` shipped `"lint": "echo \"no lint\""`.** CI printed it and went green. The backend was
  **0 % linted behind a healthy-looking gate.** Two more packages still carried the stub when we
  looked.
- **Uploaded images bypassed every normalisation.** A photographed worksheet reached a (usually US)
  vision provider with its EXIF intact — **GPS coordinates of the place a child does homework**.
- **The MIME whitelist read `file.mimetype`** — the multipart header, i.e. whatever the caller typed.
- **Not one `execFile` had a timeout.** A hung parser parks a BullMQ worker slot **forever** (BullMQ
  renews a running job's lock, so it is never even "stalled"). At concurrency *N*, **N crafted uploads
  stop generation outright.**
- **The e2e harness mocks the whole `AiService`** — document prep, sanitisation and prompt assembly
  are unreachable from any HTTP test.

---

## 4. What was lost, dropped, or never noticed

| What | Extent |
|---|---|
| **Learning gaps planted** | **0** — with learning mode *on*, a ledger created two days earlier, across ~8 implementation phases |
| The `SKIPPED` finding, reported → landed | **2 rounds.** The next upstream release touched `merge-gate.sh` in a *comment only*; the finding had not landed and had to be raised again |
| A stale memory claiming *"no ledger exists"* | False. One did. It would have silently disabled learning mode entirely |
| `## Local IDs` half-truth | Survived **one full review cycle — my own** |
| `SEC-12` missing from the ID-collision note | **Weeks** |
| `CLIENT-12` cited in the API contract, present in no catalog | **7 days** open (2026-07-07 → 07-14), and resolved only *incidentally* |
| Filed issues still open | **4 of 7** |
| Memory file corrupted by my own tooling | 1× |

### The zero is the most important number here

Learning mode was **deliberately switched on**. The ledger exists. Roughly eight implementation phases
ran. **Not one learning gap was planted.**

Every single skip had a *valid local reason* — the skill forbids planting a gap when testing or review
still runs on the branch in the same turn, and forbids it in an autopilot batch. Both rules are
correct in isolation.

**And their conjunction is a bug.** In a session where implementation is *always* followed by testing
and review (which is the workflow the suite prescribes), the plant condition is **never** satisfiable.
The mechanism the human opted into produced nothing, and did so while every individual decision was
compliant.

I applied the rule correctly eight times. **I should have noticed that a rule which never fires is not
a rule.** That is the same disease as the gate that never said GO, one layer up — and I did not see it
because each individual "skip" looked exactly like the rule working.

---

## 5. What actually worked

- **The landing rule held at 100 %.** 7 issues filed, **zero findings lost to a chat log**. Not one
  "we should also fix X" evaporated.
- **The floor caught the agent's own mistake.** The `git add -A` that smuggled a `merge-gate.sh`
  change into a security PR was caught **by the machine, not by me**.
- **The lenses are not decoration.** On the *identical diff*: `breadth` found a document **outside**
  the diff; `adversarial` found a **two-step attack chain**. Different lists. That was the test, and
  it passed.
- **Every fix that stuck was mechanised.** The rules that stayed true are the ones a script now
  enforces. The rules that only lived in prose decayed — all of them, without exception.

---

## The conclusion, stated as plainly as I can

**The value was never in the judgment.** Not mine, not the model's, not the reviewer's. Judgment was
wrong 8 times out of 8 whenever it was not checked against something that could disagree with it.

**The value was that, at the end, something *ran* and *contradicted*.**

Every rule in this suite that survived the week is a rule that became an artefact. Every rule that
stayed a paragraph decayed — including the ones written *specifically* to prevent decay. The catalog's
own Red Flag for `MAINT-8` says it best, and it was written before anyone knew how literally it would
be proved:

> *A rule that nothing enforces is not a guarantee. It is a finding you have to remember to
> re-measure, and it decays silently between audits.*

It decayed. In the document that says so.

---

*Every number here is traceable to a commit, a PR, an issue or a command output in
the production backend+web repo and the suite's origin repo, 2026-07-12 → 2026-07-14. Where a
claim could not be traced, it was omitted rather than estimated.*
