# Field report: 259 gate verdicts over 2026-07-22 → 2026-09-05 — precision 90.5 %, zero false negatives, and a gate the owner switched off anyway

**Field repo:** `fr-06287b7fb053` — the game repo of the three earlier reports, `solo` mode: the
[30-run report](2026-08-06-thirty-runs-zero-false-negatives.md), the [merged-but-not-on-main
report](2026-08-06-merged-but-not-on-main.md) and the [three-weeks
report](2026-08-12-three-weeks-of-ledger.md)
**Suite version:** vendored under `.claude/skills/` — the suite's own earlier reports on this repo
record the vendored copy at more than one version (2026-08-06, 2026-08-12) and a ledger lost to an
update, which is why a fix kept in the vendored copy cannot be relied on (Part B, finding 1)
**Window:** gate ledger 2026-07-22 (start per the 2026-08-12 report) → 2026-09-05 (259 verdicts) ·
run log 2026-08-14 → 2026-09-05 (242 rows) · invocation log 2026-08-20 → 2026-09-06 (87 rows) · 283
merged PRs over the project's life
**What ran:** the full lifecycle. Hook-counted invocations (87, a floor — Part B, finding 4):
`wai-pr-review` 28 · `wai-testing` 25 · `wai-implementation` 15 · `wai-requirements-planning` 11 ·
`wai-retro` 3 · `wai-team` 2 · `wai-learning-gap` 1 · `wai-architecture-audit` 1 · `wai` (router) 1.
Self-reported run-log rows (242): `wai-pr-review` 147 · `wai-implementation` 40 · `wai-testing`
39 · `wai-requirements-planning` 10 · `wai-retro` 3 · `wai-architecture-audit` 2 · without a skill 1.
The balance reads the distribution as reliable and the absolute counts as an undercount.
**Corpus:** 259 gate verdicts, 246 of them GO/NO-GO, **229 judged**
*(The repo's own balance of 2026-09-06, read together with § 1c of its defect report of 2026-08-31;
landed here as the dated record, translated on intake. Numbers are the repo's; nothing was
re-measured here.)*

> **Outcome note (added on intake — the findings below keep their original voice, and are true as
> of the window):** finding 1 (the citation channel, 12 of 14 false positives) is the classifier
> fix of #67 (PR #71) — the citation scan decides from added code lines only, prose is advisory,
> title and body are no longer read. Finding 4's first cause (a hook that exists only in the main
> checkout) is what `invocation-log.sh --snippet` now addresses — it names linked worktrees as the
> condition for a global hook (#68, PR #72). Finding 3's other half — a tag on a MOOT row, which
> has no rate either — is #69 (PR #73), and the ledger header clause it implies is #74.
>
> **Wording note (2026-09-15):** two sentences about the outcome column (finding 3 and *What this
> report does not answer*) were rephrased to state the measured fact without judging how the
> column was kept; no number and no finding changed.

---

## Part A — the gate, measured

### The verdicts

| Verdict | Rows | Share |
|---|---:|---:|
| NO-GO | 159 | 61 % |
| GO | 87 | 34 % |
| MOOT (PR already merged) | 10 | 4 % |
| UNKNOWN (could not check) | 3 | 1 % |

### Confusion matrix

Over the **246 GO/NO-GO rows**; MOOT and UNKNOWN are not classifications and stay out. Also out:
9 untagged rows, 4 marked `LOST`, one `?`, and the three `fn`-tagged NO-GO rows (finding 3) — 17
together. **Positive = "block".**

| | human: blocking was right | human: should have passed |
|---|---:|---:|
| **gate: NO-GO** | **134** *(correctly blocked)* | **14** *(false alarm)* |
| **gate: GO** | **0** *(nothing slipped through)* | **81** *(correctly passed)* |

| Measure | Value |
|---|---:|
| precision of a block | 134 / 148 = **90.5 %** |
| recall | 134 / 134 = **100 %** |
| accuracy | 215 / 229 = **93.9 %** |
| **false negatives (`fn`)** | **0** |

The last number is the one that matters; the ledger's own header says so (*one `fn` outweighs ten
`fp`*). Not one GO was later judged as "should have been blocked" — under the reservation in
finding 3.

### The 14 false alarms, by cause

| Cause | Rows |
|---|---:|
| `fp,bug` — a classifier defect: `EX-GDPR`/`EX-API` read from **text**, not code (the citation channel) | 8 |
| `fp` without detail | 2 |
| `EX-GDPR` from a **run-log row of another PR** that sat in the diff as context | 1 |
| `EX-GDPR` from the **prose** of three documentation files | 1 |
| `EX-API`/`EX-SEC` from the sentence *"SEC-3/API-1 not touched"* in the PR text | 1 |
| `fp,unknown` | 1 |

**Twelve of fourteen share one root** (the balance's count; the itemised table attributes eleven
rows to a text-read cause, with two `fp` and one `fp,unknown` left undetailed): the classifier read
*mentions* as *acts*. A PR that wrote
*about* erasure paths was treated like one that touched them — and because the gate ledger and the
run log ride along in every PR of this repo, it hit the PRs that had nothing to do with the topic
disproportionately.

### The quiet category: 11 × "ok, besser GO"

Eleven NO-GOs are tagged *correct, but unwanted*: the gate rightly saw a contract path, and the
owner no longer needed the hold. They are not false alarms. They are the reason for the decision in
Part C — not inaccuracy, **friction without return**. Six further NO-GOs had one reason only: **CI
was still running** when the gate was called; those rows measure the caller's patience, not the PR.

---

## Part B — where the suite was wrong, or was measured wrong

### Finding 1 · The citation channel read mentions as acts — and a local fix would not survive an update

Over the last 64 merged PRs, classified one by one (report of 2026-08-31, § 1c): 10 tagged
`EX-GDPR` — **9 through the citation channel**, none of them touching an erasure path, and 1
through `ERASURE_PATHS`, correctly; in **6 of 10** it was the **only** exclusion reason. The three
text checks in `excluded-domains.sh` had three reaches — the erasure regex read added lines of
every file, the citation scan read the whole diff plus title and body, and the variable named for
labels held title + body + labels. The repo fixed it in its vendored copy (re-measured on all 19
PRs the gate had ever tagged `EX-GDPR`: 15 tags drop, the 4 that remain are correct) and guarded
the fix with a test; the fix itself sits in a folder the next suite update overwrites, with a red
test as the only brake. **Proposal:** the change belongs upstream, not in a vendored copy.
*(Adopted — see the outcome note.)*

### Finding 2 · Six NO-GOs measured the caller, not the PR

Six rows' only reason was a required check still `IN_PROGRESS`. Correct by the rules, useless as a
verdict: it said nothing about the PR. **Proposal (the suite's, on intake — the balance makes
none):** none for the gate — it must not guess a running check green (the same evasion class as skip-to-green, which it was hardened against); the lesson is for the caller, and the ledger's `nil` tag exists for
exactly these rows.

### Finding 3 · Three `fn` tags on NO-GO rows — an instrument finding

Three NO-GO rows from 2026-08-10 and 2026-08-11, all with the same reason (*main declares no
required status checks*), carry the tag `fn`. By the ledger's definition (`fn` = *a GO that should
have blocked*) a NO-GO cannot be one; the three are either early mis-tags or meant *"blocked for
the wrong reason"*. They are not counted as slips above, and the zero stands under this reservation.
`gate-stats.sh` prints them as a data-quality line since v0.2.0 (PR #17, 2026-08-12); the balance
notes that **the column that matters most is also the one where tagging needed correction** — the
reason it is worth a regular review. (The 2026-08-12
report gave `test=IN_PROGRESS` as these rows' reason; the balance gives the required-checks reason —
a question for the source, not re-measured here.)

### Finding 4 · A guard that does not run looks exactly like a guard that finds nothing

The invocation hook — the suite's denominator — undercounted. The independent evidence is the
merged-PR comparison: on 2026-09-01, **12 merged PRs against one counted invocation**. The balance
also reads 28 hook-counted PR-review invocations against 147 run-log rows as about **a factor of
five** — Finding 5 notes that part of that ratio is legitimate. Four causes, all found:

1. The hook lived in `.claude/settings.local.json`, which is untracked and therefore exists only in
   the **main checkout** — while the repo's own instructions put every second session in a
   **linked worktree**. The sessions doing most of the work ran no hook. Moved to
   `~/.claude/settings.json` on 2026-09-03; before the move (2026-09-01 → 03) 9 invocations
   against 44 merged PRs (**20 %**), on the first full day after it **7 against 7**.
2. The script keys on `"tool_name":"Skill"`; a skill invoked by *typing* its slash command is not
   seen. A second hook writes to the same log.
3. A skill whose text is already in the context tends to be **imitated rather than invoked** —
   measured on 2026-09-02: five invocations in one session, three rows. A behaviour, not a tool
   defect, and the hardest of the four to automate away.
4. The predecessor hook lay on `main`, valid and executable, with zero rows — nobody had confirmed
   it in `/hooks`.

**Proposal:** an outside cross-check for every counter (here: hook rows against merged PRs, which
showed the defect in one line).

### Finding 5 · One review, several rows

The run log carries **5.3 rows per PR-review invocation**; a review is normally one PR. Partly
legitimate (one row per subject), partly not explained. Left open.

---

## Part C — the decision of 2026-09-06: the gate role is switched off, pre-release

The owner removed the gate's role in this project until publication: the game is tested by a human
on every change, the suite keeps being the way of working, and the PR review stays **mandatory
before every merge** — it is the part that produces findings; the gate only held them back.
`merge-gate.conf` stays, because two local guards read it: `CONTRACT_PATHS` was **emptied, not
deleted**. What changes: no `merge-gate.sh`, no hold on contract paths, no waiting for an approval
on technical changes. What changes it back: publication — users who do not sit at the same table.

The balance's own reading (its learning 6): the gate was **accurate and no longer needed** — 90.5 %
precision, zero slips, and eleven rows saying *ok, besser GO*.

---

## Part D — what the suite takes from it

- **A guard that does not run is indistinguishable from one that finds nothing** — twice in this
  window (the hook never confirmed; the hook in the wrong checkout). Every counter needs a
  cross-check from outside itself.
- **The counterproof is the single most valuable mechanism.** In two PRs of 2026-09-05/06, 30
  counterproofs ran and **3 survived** — each found something real: two assertions that checked
  nothing (one over 566 zeros of 576 cells), one condition no test could turn red, since removed.
  **10 % of counterproofs found what the green run would not have shown.**
- **The recurring defect is not wrong code but code never called.** Five times in four weeks a
  function was defined, tested, counterproofed — and never called by production. The test was green
  because it called the function directly. *Sabotage the production line, not the helper.*
- **A sabotage anchor that occurs twice in a file hits the wrong line** — four times; the
  counterproof reported "survived" while the assertion was fine. Count the anchor before replacing.
- **Derived lists hold, typed lists drift** — every list that existed twice in the project drifted
  at least once (a module map, a key list, a parameter table).

## What this report does not answer

- How much suite really ran is an estimate: the denominator is reliable only since 2026-09-03; the
  87 invocations are a floor.
- Whether the zero false negatives hold, only time tells — an `fn` often surfaces weeks later, and
  the three mis-tagged rows show that the column it depends on is the one most worth a regular
  review.
- Whether friction was the reason or the occasion: the next balance should measure findings per
  PR before and after the switch-off.

## gate-stats output

The balance did not paste the raw `gate-stats.sh` output; the tables in Part A are its extract
(verdict counts, judged rows, `fp`/`fn`, the *besser GO* line, the NO-GO causes it itemised).

---

*The field-repo identifier `fr-06287b7fb053` is a keyed hash of the repository URL. The key is
random, generated once per reporting repo, and never leaves the reporter — so the same identifier
groups all reports from one repo without naming it, and no outside party can confirm a guessed URL
against it.*
