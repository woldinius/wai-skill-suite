# Field report: two months of gate ledger, 259 verdicts — precision 90.5 %, zero false negatives, and a gate the owner switched off anyway

**Field repo:** `fr-06287b7fb053` — a browser game (JavaScript, deterministic simulation), `solo`
mode; the same repo as the [30-run report](2026-08-06-thirty-runs-zero-false-negatives.md) and the
[three-weeks report](2026-08-12-three-weeks-of-ledger.md)
**Suite version:** vendored under `.claude/skills/`, updated through the window — which is why the
repo's own fix to the classifier did not survive (Part B, finding 1)
**Window:** gate ledger to 2026-09-05 (259 verdicts) · run log 2026-08-14 → 2026-09-05 (242 rows) ·
invocation log 2026-08-20 → 2026-09-06 (87 rows) · 283 merged PRs over the project's life
**Corpus:** 259 gate verdicts, 246 of them GO/NO-GO, **229 judged**
*(The repo's own balance of 2026-09-06, read together with its defect report of 2026-08-31; landed
here as the dated record, translated on intake. Numbers are the repo's; nothing was re-measured
here.)*

> **Outcome note (added on intake — the findings below keep their original voice, and are true as
> of the window):** finding 1 (the citation channel, 12 of 14 false positives) is the classifier
> fix of #67 (PR #71) — the citation scan decides from added code lines only, prose is advisory,
> title and body are no longer read. Finding 4's second half (a hook that exists only in the main
> checkout) is why `invocation-log.sh --snippet` now names linked worktrees as the condition for a
> global hook, and why `open-items.sh` lists rows that exist only in a worktree (#68, PR #72).
> Finding 3 (tags on rows that have no rate) is #69 (PR #73), and the ledger header clause it implies is #74. At publication, #71–#73 were open, stacked, and awaiting the human merge each requires.

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

**Twelve of fourteen share one root:** the classifier read *mentions* as *acts*. A PR that wrote
*about* erasure paths was treated like one that touched them — and because the gate ledger and the
run log ride along in every PR of this repo, it hit the PRs that had nothing to do with the topic
first.

### The quiet category: 11 × "ok, besser GO"

Eleven NO-GOs are tagged *correct, but unwanted*: the gate rightly saw a contract path, and the
owner no longer needed the hold. They are not false alarms. They are the reason for the decision in
Part C — not inaccuracy, **friction without return**. Six further NO-GOs had one reason only: **CI
was still running** when the gate was called; those rows measure the caller's patience, not the PR.

---

## Part B — where the suite was wrong, or was measured wrong

### Finding 1 · The citation channel read mentions as acts — and the local fix did not survive an update

Over the last 64 merged PRs, classified one by one (report of 2026-08-31, § 1c): 10 tagged
`EX-GDPR`, **9 through the citation channel**, none touching an erasure path; in **6 of 10** it was
the **only** exclusion reason. The three text checks in `excluded-domains.sh` had three reaches — the
erasure regex read added lines of every file, the citation scan read the whole diff plus title and
body, and the variable named for labels held title + body + labels. The repo fixed it in its
vendored copy (15 of 19 tags drop, the 4 that remain are correct) and guarded the fix with a test —
a folder the next suite update overwrites, with a red test as the only brake.
**Proposal:** the change belongs upstream, not in a vendored copy. *(Adopted — see the outcome note.)*

### Finding 2 · Six NO-GOs measured the caller, not the PR

Six rows' only reason was a required check still `IN_PROGRESS`. Correct by the rules, useless as a
verdict: the same PR a minute later was GO. **Proposal:** none for the gate — it must not guess a
running check green (that is the skip-to-green class it was hardened against); the lesson is for the
caller, and the ledger's `nil` tag exists for exactly these rows.

### Finding 3 · Three `fn` tags on NO-GO rows — an instrument finding

Three NO-GO rows from 2026-08-10 and 2026-08-11, all with the same reason (*main declares no
required status checks*), carry the tag `fn`. By the ledger's definition (`fn` = *a GO that should
have blocked*) a NO-GO cannot be one; the three are either early mis-tags or meant *"blocked for
the wrong reason"*. They are not counted as slips above, and the zero stands under this reservation.
`gate-stats.sh` prints them as a data-quality line since v0.2.0; the balance notes that **the column
that matters most was the one maintained least carefully**.

### Finding 4 · A guard that does not run looks exactly like a guard that finds nothing

The invocation hook — the suite's denominator — undercounted by about **a factor of five**: 28
hook-counted PR-review invocations against 147 run-log rows for the same skill; on 2026-09-01,
**12 merged PRs against one counted invocation**. Four causes, all found:

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
showed the defect in one line), and a snippet that says *why* the opt-in lives where it lives and
*when* the global file is the right place.

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

The suite's reading: the gate was **accurate and no longer needed** — 90.5 % precision, zero slips,
and eleven rows saying *ok, besser GO*. A gate is not judged by its confusion matrix alone; it is
judged by whether the person it holds still wants to be held.

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
- **Derived lists hold, typed lists drift** — every list that existed twice in the project drifted at
  least once (a module map, a key list, a parameter table).

## What this report does not answer

- How much suite really ran is an estimate: the denominator is reliable only since 2026-09-03; the
  87 invocations are a floor.
- Whether the zero false negatives hold, only time tells — an `fn` often surfaces weeks later, and
  the three mis-tagged rows show that the column it depends on was the least carefully kept.
- Whether friction was the reason or the occasion: the next balance should measure findings per
  PR before and after the switch-off.

## gate-stats output

The balance did not paste the raw `gate-stats.sh` output; the tables in Part A are its extract
(verdict counts, judged rows, `fp`/`fn`, the *besser GO* line, the NO-GO causes it itemised).
