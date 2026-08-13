# Field report: three weeks of gate ledger, measured — 85 verdicts, 82 human-tagged, and the 0% that was really 15%

**Field repo:** `fr-06287b7fb053` — a game-server repo, `solo` mode; the same repo as the
[30-run report](2026-08-06-thirty-runs-zero-false-negatives.md)
**Suite version:** `bdb3cdf` · **Window:** 2026-07-22 → 2026-08-12
**Corpus:** 85 gate verdicts, **82 human-tagged**, alongside 115 merged PRs
*(Filed as suite issue #10; landed here as the dated record.)*

> **Outcome note (added on intake — the findings below keep their original voice, and are true
> as of the window):** findings 1–4 were implemented in PR #17 (tag matching on the first two
> characters + unmatched count, the `besser GO` calibration metric, reasons-first ledger cells,
> `NO-GO/fn` reported separately). The run-log proposal — Part B's most important — is in build
> as issues #11 and #14. Proposal 7, protecting the ledger across suite updates, is the reason
> the installer now carries an explicit ledger guarantee and a test that fails the day an update
> can touch `docs/` — added alongside this report.

---

## Part A — the gate, measured

### The data

| Verdict | `ok` | `fp` | `fn` | untagged |
|---|---|---|---|---|
| NO-GO | **44** | 8 | 3 | 1 |
| GO | 19 | 0 | 0 | 1 |
| MOOT | 4 | 1 | 0 | 1 |

The human's tag vocabulary turned out finer than the two letters — and the suffixes carry
information the tooling currently throws away:

| Tag (verbatim) | Meaning | Count |
|---|---|---|
| `ok` | verdict was right | 32 |
| `ok, besser GO` | right — *but the gate could safely have said GO here* | **11** |
| `ok, manual fix` / `ok, manual pr` | right; the human intervened themselves | 3 |
| `fp, bug` | false alarm, caused by a defect in the gate | 8 |

**Real false-positive rate: 8 of 52 judged NO-GOs = 15 %.**

### Finding 1 · `gate-stats.sh` matches tags exactly — and silently drops 20 of 52 rows

The parser compares `outcome["NO-GO/ok"]` literally. `fp, bug` is not `fp`; `ok, besser GO`
is not `ok`. Twenty judged NO-GO rows fall out of the statistic, unannounced, and the output
reads:

    1.1  false-positive rate:  0 of 32 judged NO-GOs = 0%

The true value is **15 %**. The zero is not a measurement — it is a parser artifact, sitting
in the very line meant to prove the gate trustworthy.
**Proposal:** match on the first two characters (that is how the vocabulary is meant), and
print the count of unmatched tags. A statistic that drops rows must say so. *(Build input
for #8.)*

### Finding 2 · `ok, besser GO` is a calibration dial — and nobody reads it

Eleven times (21 % of judged NO-GOs) the human recorded: *the block was correct per the
rules, but GO would have been fine here.* That is the most precise feedback a gate can
receive — a calibration instruction with evidence attached. It is currently invisible to
every script and every skill, and the gate has been unchanged for three weeks.
**Proposal:** a dedicated metric ("21 % of correct NO-GOs were unwanted — recurring
patterns: …"). Irrelevant for correctness; the single most important number for
**usefulness**. *(Build input for #8.)*

### Finding 3 · The reason still does not survive the cap — measured, and hand-repaired

Of 56 NO-GO rows, 7 cite an excluded domain; exactly **one** still carries readable domain
names. The cap fix (cap400) removed mid-word cuts, but the **ordering** remained: passed
checks first, failed checks last — **median 143 characters of preamble before the first ✗**.
Over a third of the budget is spent on "everything fine", and the cut lands where the
decision lives. The human has been reconstructing the missing domain names **by hand** as
ledger comments — the most expensive possible evidence that the tool does not deliver here.
**Proposal:** failed checks first, passed checks after. Two lines. *(Confirms #8 part 1,
now with a measured median.)*

### Finding 4 · The three `fn` tags are CI-timing, not misses

All three carry the identical reason `test=IN_PROGRESS`: NO-GOs that blocked because CI was
still running. A NO-GO cannot be a *"should have blocked and did not"* — `fn` is only
defined on GO rows. Yet the statistic counts them under the headline *"one of these
outweighs ten false positives."* **The number that makes the case currently measures
something other than what it claims.**
**Proposal:** a tag for verdicts that say nothing about the code (e.g. `nil`), and restrict
`fn` to GO rows; until then, report `NO-GO/fn` separately. *(Build input for #8.)*

### Finding 5 · In this repo the gate is 98 % a setup guard

55 of 56 NO-GOs failed on **environment**, not domain: no required checks declared, no
enforced approval, a check still running. Not wrong — but it shifts what the gate does. The
remedy is printed in every affected row (*"declare required checks on main"*) — **55 times,
unread**. Together with the eleven `besser GO` rows the picture is unambiguous: this repo
has a **checks problem, not a domain problem**, and the gate has been saying so for three
weeks.
**Proposal:** break NO-GOs down by cause (setup / checks / domain) in the stats. It turns
"56 NO-GOs" into something a human can act on. *(Build input for #8.)*

## Part B — the suite

### The most important gap: runs leave no trace

A security audit ran in this window — no verdict, no issue, no line anywhere. An eight-issue
orchestrator run produced two PRs — the protocol does not know it happened. A skill only
leaves a trace when it emits a **gate verdict** or **creates an issue**; an audit that finds
nothing, a batch run that bundles, a planning pass that comments on an existing issue are
all invisible. **The protocol measures the side effects of work, not the work.**
**Proposal — the most important in this report:** an append-only **run log** next to the
gate ledger. One line per skill run: timestamp, skill, subject, result in half a sentence;
written by a script, like the ledger. Only then do these questions become answerable: how
often do audits run? what does planning yield? what does a batched run cost against N
single runs?

### Issue counts measure only the review step

Counting issues by originating skill misleads: planning posts its results as a **comment on
the driving issue**, not as a new issue — so issue counts say nothing about what planning
or audits contribute. What the count does show: **58 issues originate from the review
step** — the stage that lands findings as standalone, durable units. That is consistent
with the July statistics report (*"of 47 defects found in a week, 0 were found by
thinking"*). The contribution of the other stages is unmeasurable today — see the run-log
gap above.

### The window is shorter than it looks

The ledger starts 2026-07-22 — everything before was **lost in a suite update**; otherwise
there would be measurements from late June. 85 verdicts against 115 PRs is partly explained
by that, not by skipped runs.
**Proposal:** the ledger is append-only experience that cannot be reconstructed. A suite
update that can delete it is a data-loss risk — treat it as a migration path, not as a file.

### What demonstrably held

- **Derived lists over maintained ones.** Five separate findings of the same class in three
  weeks (a sum, a counter, a filename list, a module list — each maintained by hand in two
  places, each caught by review only after being built). No skill names this class yet.
- **The counterproof.** Every assertion that stayed green regardless of the code was found
  by sabotage, never at writing time.
- **The gate as artifact, not memory.** That "I checked" becomes a row is the reason this
  report can exist at all.

### The result above the numbers

**Three weeks, 115 merged PRs, zero technical failures.** No exception, no crash, no
corrupted state file. Re-measured in a live session: 14 runs with the real tick code,
**zero errors logged** — in a codebase that deliberately fails loud when a tunable is
missing. Every defect found in the window was a **domain-design question, not a software
failure**. That a codebase changed daily for three weeks stays continuously runnable is the
strongest single result of this measurement — and the only one no ledger metric captures.

## The proposals, mapped

| # | Proposal | Where it lands |
|---|---|---|
| 1 | Append-only **run log** next to the gate ledger | new |
| 2 | Tag matching on first two characters + unmatched count | #8, build input |
| 3 | `ok, besser GO` as a dedicated calibration metric | #8, build input |
| 4 | Failed checks **first** in the why cell (median 143 chars of preamble measured) | #8, part 1 confirmed |
| 5 | `nil` tag; `fn` restricted to GO rows | #8, build input |
| 6 | NO-GO cause breakdown (setup / checks / domain) | #8, build input |
| 7 | Protect the ledger across suite updates (migration path, not file) | new |

---

*The field-repo identifier `fr-06287b7fb053` is a keyed hash of the repository URL. The key
is random, generated once per reporting repo, and never leaves the reporter — so the same
identifier groups all reports from one repo without naming it, and no outside party can
confirm a guessed URL against it. Any repo can mint its own; generating the key is intended
to become part of the suite's init/retro tooling.*
